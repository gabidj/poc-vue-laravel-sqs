<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class ConsumeSQS extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'queue:consume-sqs
                            {--tries=3 : Number of times to attempt a job before logging it failed}
                            {--timeout=300 : The number of seconds a child process can run}
                            {--sleep=3 : Number of seconds to sleep when no job is available}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Consume messages from AWS SQS queue';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('Starting SQS consumer...');
        $this->info('Queue: ' . config('queue.connections.sqs.queue'));
        $this->info('Region: ' . config('queue.connections.sqs.region'));

        $this->call('queue:work', [
            'connection' => 'sqs',
            '--tries' => $this->option('tries'),
            '--timeout' => $this->option('timeout'),
            '--sleep' => $this->option('sleep'),
            '--max-jobs' => 0, // Process indefinitely
            '--verbose' => true,
        ]);
    }
}
