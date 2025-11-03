<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessRequest implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $requestData;

    /**
     * Create a new job instance.
     */
    public function __construct($requestData)
    {
        $this->requestData = $requestData;
    }

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        Log::info('Processing request from queue', [
            'data' => $this->requestData,
            'source' => $this->requestData['source'] ?? 'unknown',
            'received_at' => $this->requestData['received_at'] ?? null,
        ]);

        // Your actual processing logic here
        // Example: Create a record, send email, process payment, etc.

        // For now, just logging what was received
        Log::info('Request processed successfully', [
            'job_id' => $this->job?->getJobId(),
            'queue' => $this->queue,
        ]);
    }
}
