<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('stock_histories', function (Blueprint $table) {
            $table->id();

            $table->foreignId('stock_id')
                ->constrained('stocks')
                ->cascadeOnUpdate()
                ->cascadeOnDelete();

            $table->foreignId('product_id')
                ->constrained('products')
                ->cascadeOnUpdate()
                ->restrictOnDelete();

            $table->integer('qty');
            $table->string('unit', 20);

            $table->timestamp('logged_at')->useCurrent();

            $table->timestamps();

            $table->foreignId('actor_user_id')->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->index(['product_id', 'logged_at']);
            $table->index(['stock_id', 'logged_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_histories');
    }
};
