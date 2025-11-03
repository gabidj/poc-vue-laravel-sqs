# Complete Guide: AWS API Gateway + SQS + Laravel Integration

This guide will help you set up AWS API Gateway and SQS to work with your Laravel application for handling traffic spikes.

## Architecture Overview

```
Client Request
    ↓
API Gateway → SQS Queue
                ↓
          Laravel Queue Worker (php artisan queue:work sqs)
                ↓
          ProcessRequest Job
```

## Part 1: AWS Console Setup

### Step 1: Create SQS Queue

1. **Navigate to SQS**
   - Go to AWS Console → Services → SQS
   - Click "Create queue"

2. **Configure Queue**
   - **Type**: Standard Queue (or FIFO if order matters - name must end with `.fifo`)
   - **Name**: `laravel-requests-queue` (or `laravel-requests-queue.fifo` for FIFO)
   - **Configuration**:
     - Visibility timeout: `300` seconds (5 minutes) - adjust based on your job processing time
     - Message retention: `345600` seconds (4 days)
     - Delivery delay: `0` seconds
     - Maximum message size: `256 KB`
     - Receive message wait time: `0` seconds (or `20` for long polling)
   - Click "Create queue"

3. **Note the Queue Details**
   - **Queue URL**: Example: `https://sqs.us-east-1.amazonaws.com/123456789012/laravel-requests-queue`
   - **Queue ARN**: Example: `arn:aws:sqs:us-east-1:123456789012:laravel-requests-queue`
   - Save these for later configuration

### Step 2: Create IAM User for Laravel (Consumer)

1. **Navigate to IAM**
   - Go to AWS Console → IAM → Users
   - Click "Create user"

2. **User Details**
   - Username: `laravel-sqs-consumer`
   - Click "Next"

3. **Set Permissions**
   - Select "Attach policies directly"
   - Click "Create policy"
   - Use JSON editor and paste:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes",
                "sqs:ChangeMessageVisibility"
            ],
            "Resource": "arn:aws:sqs:us-east-1:123456789012:laravel-requests-queue"
        }
    ]
}
```

   - **Replace** the ARN with your queue's ARN (found in SQS queue details)
   - Name it: `LaravelSQSConsumerPolicy`
   - Click "Create policy"
   - Go back to the user creation and attach this policy

4. **Create Access Keys**
   - Select the user → "Security credentials" tab
   - Click "Create access key"
   - Select "Application running outside AWS"
   - Click "Next" and then "Create access key"
   - **Save these credentials - you'll need them**:
     - Access Key ID
     - Secret Access Key

### Step 3: Create API Gateway

1. **Navigate to API Gateway**
   - Go to AWS Console → API Gateway
   - Click "Create API"

2. **Choose API Type**
   - Select **"REST API"** (not private)
   - Click "Build"

3. **API Details**
   - **API name**: `LaravelRequestAPI`
   - **Description**: Routes requests to SQS for Laravel processing
   - **Endpoint Type**: Regional
   - Click "Create API"

4. **Create Resource**
   - Click "Actions" → "Create Resource"
   - **Resource Name**: `request`
   - **Resource Path**: `/request`
   - Enable **CORS** if needed (check the box)
   - Click "Create Resource"

5. **Create POST Method**
   - Select the `/request` resource
   - Click "Actions" → "Create Method"
   - Select "POST" from dropdown
   - Click the checkmark

### Step 4: Create IAM Role for API Gateway

Before configuring the integration, create a role for API Gateway to access SQS:

1. **Navigate to IAM → Roles**
   - Click "Create role"
   - **Trusted entity type**: AWS Service
   - **Use case**: API Gateway
   - Click "Next"

2. **Create Custom Policy**
   - Click "Create policy"
   - Use JSON editor:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:SendMessage",
                "sqs:GetQueueUrl"
            ],
            "Resource": "arn:aws:sqs:us-east-1:123456789012:laravel-requests-queue"
        }
    ]
}
```

   - **Replace** the ARN with your queue's ARN
   - **Name**: `APIGatewayToSQSPolicy`
   - Click "Create policy"

3. **Finish Role Creation**
   - Go back to role creation
   - Search for and attach `APIGatewayToSQSPolicy`
   - **Role name**: `APIGatewayToSQSRole`
   - Click "Create role"
   - **Copy the Role ARN** - you'll need it in the next step

### Step 5: Configure API Gateway Integration

1. **Integration Setup (click on POST method)**
   - **Integration type**: AWS Service
   - **AWS Region**: Select your region (e.g., `us-east-1`)
   - **AWS Service**: SQS
   - **AWS Subdomain**: Leave empty
   - **HTTP method**: POST
   - **Action Type**: Use path override
   - **Path override**: Enter your AWS Account ID and queue name:
     ```
     /YOUR_AWS_ACCOUNT_ID/laravel-requests-queue
     ```
     Example: `/123456789012/laravel-requests-queue`
   - **Execution role**: Paste the Role ARN from Step 4
   - Click "Save"

2. **Integration Request Configuration**
   - Click on "Integration Request"
   - Scroll to **"HTTP Headers"**
   - Click "Add header":
     - **Name**: `Content-Type`
     - **Mapped from**: `'application/x-www-form-urlencoded'`
   - Scroll to **"Mapping Templates"**
   - **Request body passthrough**: When there are no templates defined (recommended)
   - Click "Add mapping template"
   - **Content-Type**: `application/json`
   - Click the checkmark
   - **Template** (paste this):

```vtl
Action=SendMessage&MessageBody=$input.body
```

   - Click "Save"

3. **Integration Response Configuration**
   - Click on "Integration Response"
   - Expand the **"200"** response
   - Click on **"Mapping Templates"**
   - Click "Add mapping template"
   - **Content-Type**: `application/json`
   - **Template**:

```json
{
    "message": "Request queued successfully"
}
```

   - Click "Save"

4. **Method Response** (optional)
   - Should already have 200 status code
   - You can add 500 for errors if desired

### Step 6: Deploy API

1. **Deploy the API**
   - Click "Actions" → "Deploy API"
   - **Deployment stage**: [New Stage]
   - **Stage name**: `prod`
   - Click "Deploy"

2. **Note Your Invoke URL**
   - You'll see something like: `https://abc123.execute-api.us-east-1.amazonaws.com/prod`
   - **Your endpoint is**: `https://abc123.execute-api.us-east-1.amazonaws.com/prod/request`
   - Save this URL for testing

## Part 2: Laravel Configuration

### Step 1: Configure Environment Variables

Create or update your `.env` file with the following AWS credentials and SQS configuration:

```env
# Queue Configuration
QUEUE_CONNECTION=sqs

# AWS Credentials (from Step 2 of AWS setup)
AWS_ACCESS_KEY_ID=your_access_key_from_iam
AWS_SECRET_ACCESS_KEY=your_secret_key_from_iam
AWS_DEFAULT_REGION=us-east-1

# SQS Configuration
SQS_PREFIX=https://sqs.us-east-1.amazonaws.com/123456789012
SQS_QUEUE=laravel-requests-queue
SQS_SUFFIX=
```

**Note**: Replace the values with your actual AWS credentials and queue information from Part 1.

### Step 2: Verify Queue Configuration

The SQS configuration is already present in `config/queue.php`:

```php
'sqs' => [
    'driver' => 'sqs',
    'key' => env('AWS_ACCESS_KEY_ID'),
    'secret' => env('AWS_SECRET_ACCESS_KEY'),
    'prefix' => env('SQS_PREFIX'),
    'queue' => env('SQS_QUEUE'),
    'suffix' => env('SQS_SUFFIX'),
    'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    'after_commit' => false,
],
```

## Part 3: Testing & Running

### Run Laravel Queue Worker

You have three options to run the queue worker:

**Option 1: Using the custom command**
```bash
php artisan queue:consume-sqs
```

**Option 2: Direct queue:work command**
```bash
php artisan queue:work sqs --tries=3 --timeout=300
```

**Option 3: With verbose output for debugging**
```bash
php artisan queue:work sqs --tries=3 --timeout=300 -vvv
```

### Test Direct HTTP Endpoint (Bypass API Gateway)

Test the direct Laravel endpoint to ensure it's working:

```bash
curl -X POST http://localhost:8000/api/request \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 123,
    "action": "test",
    "data": {
      "key": "value"
    }
  }'
```

Expected response:
```json
{
    "message": "Request received and queued",
    "source": "direct_http"
}
```

### Test API Gateway → SQS → Laravel

Test the full AWS integration:

```bash
curl -X POST https://abc123.execute-api.us-east-1.amazonaws.com/prod/request \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 456,
    "action": "api_gateway_test",
    "data": {
      "key": "value"
    }
  }'
```

Expected response from API Gateway:
```json
{
    "message": "Request queued successfully"
}
```

Then check your Laravel logs (`storage/logs/laravel.log`) to see the processed request.

## Part 4: Production Deployment

### For Local Development

Since Laravel acts as a consumer (pulls from SQS), you don't need ngrok/expose for the SQS integration. You only need it if you want direct HTTP requests to reach your local machine.

**If you want direct HTTP access:**
```bash
# Install and run ngrok
ngrok http 8000

# Then use the ngrok URL for direct requests
# http://your-ngrok-url.ngrok.io/api/request
```

### For Production

1. **Deploy Laravel to AWS EC2, ECS, or Laravel Forge**

2. **Use Supervisor to keep queue workers running**

Create `/etc/supervisor/conf.d/laravel-worker.conf`:

```ini
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/your/app/artisan queue:work sqs --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=4
redirect_stderr=true
stdout_logfile=/path/to/your/app/storage/logs/worker.log
stopwaitsecs=3600
```

Start the workers:
```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start laravel-worker:*
```

## Part 5: Monitoring & Troubleshooting

### Check Queue Status

You can add this to your `routes/api.php` for monitoring:

```php
Route::get('/queue/status', function () {
    $sqs = app('aws')->createClient('sqs');
    $result = $sqs->getQueueAttributes([
        'QueueUrl' => config('queue.connections.sqs.prefix') . '/' . config('queue.connections.sqs.queue'),
        'AttributeNames' => ['All']
    ]);

    return response()->json($result['Attributes']);
});
```

### Common Issues

1. **Access Denied Error**
   - Check IAM permissions are correctly configured
   - Verify AWS credentials in `.env`
   - Ensure the Role ARN is correct in API Gateway

2. **Messages Not Processing**
   - Check queue worker is running: `ps aux | grep "queue:work"`
   - Check Laravel logs: `tail -f storage/logs/laravel.log`
   - Verify SQS queue has messages in AWS Console

3. **API Gateway Returns Error**
   - Check CloudWatch logs in AWS Console
   - Verify the mapping template is correct
   - Test the SQS integration directly in API Gateway console

### View Logs

**Laravel logs:**
```bash
tail -f storage/logs/laravel.log
```

**Queue worker output:**
```bash
php artisan queue:work sqs -vvv
```

## Summary

✅ **AWS Console**: API Gateway → SQS (you send messages)
✅ **Laravel App**: Consumes from SQS (you receive messages)
✅ **No ngrok needed** for SQS consumption
✅ **Dual mode**: Direct HTTP `/api/request` + SQS consumption

Your Laravel app will handle both:
- **Direct HTTP requests**: `POST /api/request`
- **SQS messages**: `php artisan queue:consume-sqs` or `php artisan queue:work sqs`

## Load Balancing Strategy

The architecture supports:
- **Direct HTTP** → Laravel `/api/request` (for normal traffic)
- **API Gateway** → SQS → Laravel (for traffic spikes)

Later, you can fully migrate to API Gateway by pointing all traffic there.
