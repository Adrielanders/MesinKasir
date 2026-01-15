<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Stock extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'unit',
        'unitmeasure',
        'qty',
        'buy_price',
        'active',
    ];

    protected $casts = [
        'qty' => 'integer',
        'buy_price' => 'integer',
        'active' => 'boolean',
    ];

    public function products()
    {
        return $this->belongsToMany(Product::class, 'product_stock')
            ->withPivot(['id', 'qty', 'active'])
            ->withTimestamps();
    }
}
