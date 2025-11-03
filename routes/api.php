<?php

use App\Jobs\ProcessRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/request', function (Request $request) {
    $data = $request->all();
    $data['source'] = 'direct_http';
    $data['received_at'] = now()->toIso8601String();

    ProcessRequest::dispatch($data);

    return response()->json([
        'message' => 'Request received and queued',
        'source' => 'direct_http',
    ]);
});
