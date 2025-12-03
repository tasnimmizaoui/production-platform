package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	ctx         = context.Background()
	redisClient *redis.Client

	// Prometheus metrics
	tasksProcessed = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "worker_tasks_processed_total",
			Help: "Total number of tasks processed",
		},
	)

	taskProcessingDuration = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "worker_task_processing_duration_seconds",
			Help:    "Task processing duration",
			Buckets: prometheus.DefBuckets,
		},
	)

	tasksFailed = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "worker_tasks_failed_total",
			Help: "Total number of tasks that failed",
		},
	)

	queueLength = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "worker_queue_length",
			Help: "Current length of task queue",
		},
	)
)

type Task struct {
	ID        string    `json:"id"`
	Payload   string    `json:"payload"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func main() {
	// Initialize Redis
	redisAddr := getEnv("REDIS_ADDR", "localhost:6379")
	redisClient = redis.NewClient(&redis.Options{
		Addr: redisAddr,
	})

	// Test Redis connection
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	log.Println("✅ Connected to Redis")

	// Start HTTP server for health checks and metrics
	go startHTTPServer()

	// Start worker loop
	go startWorker()

	// Wait for interrupt
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 Shutting down worker...")
}

func startHTTPServer() {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/ready", readyHandler)
	mux.Handle("/metrics", promhttp.Handler())

	port := getEnv("PORT", "8081")
	log.Printf("🚀 Worker metrics server starting on port %s", port)
	
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Metrics server failed: %v", err)
	}
}

func startWorker() {
	pollInterval := 2 * time.Second
	log.Printf("🔄 Worker started (polling every %v)", pollInterval)

	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	for range ticker.C {
		processNextTask()
	}
}

func processNextTask() {
	// Update queue length metric
	queueLen, _ := redisClient.LLen(ctx, "task:queue").Result()
	queueLength.Set(float64(queueLen))

	// Pop task from queue
	result, err := redisClient.RPop(ctx, "task:queue").Result()
	if err == redis.Nil {
		// Queue empty
		return
	} else if err != nil {
		log.Printf("❌ Failed to pop from queue: %v", err)
		return
	}

	taskID := result
	log.Printf("📝 Processing task: %s", taskID)

	start := time.Now()

	// Get task details
	taskJSON, err := redisClient.Get(ctx, "task:"+taskID).Result()
	if err != nil {
		log.Printf("❌ Failed to get task %s: %v", taskID, err)
		tasksFailed.Inc()
		return
	}

	var task Task
	if err := json.Unmarshal([]byte(taskJSON), &task); err != nil {
		log.Printf("❌ Failed to unmarshal task %s: %v", taskID, err)
		tasksFailed.Inc()
		return
	}

	// Update status to processing
	task.Status = "processing"
	task.UpdatedAt = time.Now()
	updateTask(&task)

	// Simulate actual work
	if err := processTaskPayload(&task); err != nil {
		log.Printf("❌ Task %s failed: %v", taskID, err)
		task.Status = "failed"
		tasksFailed.Inc()
	} else {
		log.Printf("✅ Task %s completed", taskID)
		task.Status = "completed"
		tasksProcessed.Inc()
	}

	task.UpdatedAt = time.Now()
	updateTask(&task)

	duration := time.Since(start).Seconds()
	taskProcessingDuration.Observe(duration)
}

func processTaskPayload(task *Task) error {
	// Simulate processing work
	// In real scenario, this would be actual business logic
	processingTime := time.Duration(2+len(task.Payload)%5) * time.Second
	
	log.Printf("⏳ Processing task %s for %v", task.ID, processingTime)
	time.Sleep(processingTime)
	
	// Simulate occasional failures (10% failure rate for demo)
	if len(task.Payload)%10 == 0 {
		return &TaskError{Message: "simulated processing failure"}
	}
	
	return nil
}

func updateTask(task *Task) {
	taskJSON, _ := json.Marshal(task)
	redisClient.Set(ctx, "task:"+task.ID, taskJSON, 24*time.Hour)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	// Check Redis connection
	if err := redisClient.Ping(ctx).Err(); err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{"status": "not ready", "reason": "redis unavailable"})
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

type TaskError struct {
	Message string
}

func (e *TaskError) Error() string {
	return e.Message
}