<?php

namespace App\Http\Controllers\Product;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Stock;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Database\QueryException;

class StockController extends Controller
{
    private function ensureAdmin(Request $request): void
    {
        $role = $request->user()->role ?? null;
        if ($role !== 'admin') {
            abort(Response::HTTP_FORBIDDEN, 'Forbidden (admin only)');
        }
    }

    public function index(Request $request)
    {
        $stocks = Stock::query()
            ->orderBy('name')
            ->get();

        return response()->json([
            'message' => 'OK',
            'data' => $stocks,
        ]);
    }

    public function store(Request $request)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:80', 'unique:stocks,name'],
            'unit' => ['required', 'in:pcs,gram,kg'],
            'qty' => ['nullable', 'integer', 'min:0'],
            'buy_price' => ['nullable', 'integer', 'min:0'],
            'active' => ['nullable', 'boolean'],
        ]);

        $stock = Stock::create([
            'name' => $validated['name'],
            'unit' => $validated['unit'],
            'qty' => (int) ($validated['qty'] ?? 0),
            'buy_price' => (int) ($validated['buy_price'] ?? 0),
            'active' => (bool) ($validated['active'] ?? true),
        ]);

        return response()->json([
            'message' => 'Stock created',
            'data' => $stock,
        ], Response::HTTP_CREATED);
    }

    public function update(Request $request, Stock $stock)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:80', 'unique:stocks,name,' . $stock->id],
            'unit' => ['sometimes', 'required', 'in:pcs,gram,kg'],
            'qty' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'buy_price' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'active' => ['sometimes', 'nullable', 'boolean'],
        ]);

        $stock->fill($validated);

        if (array_key_exists('qty', $validated) && $validated['qty'] === null) {
            $stock->qty = 0;
        }

        if (array_key_exists('buy_price', $validated) && $validated['buy_price'] === null) {
            $stock->buy_price = 0;
        }

        $stock->save();

        return response()->json([
            'message' => 'Stock updated',
            'data' => $stock,
        ]);
    }

    public function destroy(Request $request, Stock $stock)
    {
        $this->ensureAdmin($request);

        try {
            $stock->delete();
        } catch (QueryException $e) {
            return response()->json([
                'message' => 'Stock tidak bisa dihapus karena masih dipakai product',
            ], Response::HTTP_CONFLICT);
        }

        return response()->json([
            'message' => 'Stock deleted',
        ]);
    }

    public function productStocks(Request $request, Product $product)
    {
        $data = $product->stocks()
            ->orderBy('stocks.name')
            ->get()
            ->map(function ($s) {
                return [
                    'id' => $s->id,
                    'name' => $s->name,
                    'unit' => $s->unit,
                    'qty' => $s->qty,
                    'buy_price' => $s->buy_price,
                    'active' => $s->active,
                    'pivot' => [
                        'id' => $s->pivot->id,
                        'qty' => $s->pivot->qty,
                        'active' => $s->pivot->active,
                    ],
                ];
            });

        return response()->json([
            'message' => 'OK',
            'data' => $data,
        ]);
    }

    public function attachToProduct(Request $request, Product $product)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'stock_id' => ['required', 'integer', 'exists:stocks,id'],
            'qty' => ['required', 'integer', 'min:0'],
            'active' => ['nullable', 'boolean'],
        ]);

        $product->stocks()->syncWithoutDetaching([
            (int) $validated['stock_id'] => [
                'qty' => (int) $validated['qty'],
                'active' => (bool) ($validated['active'] ?? true),
            ],
        ]);

        return response()->json([
            'message' => 'Attached',
        ]);
    }

    public function updateProductStock(Request $request, Product $product, Stock $stock)
    {
        $this->ensureAdmin($request);

        $exists = $product->stocks()
            ->where('stocks.id', $stock->id)
            ->exists();

        if (!$exists) {
            return response()->json([
                'message' => 'Stock belum terpasang di product ini',
            ], Response::HTTP_NOT_FOUND);
        }

        $validated = $request->validate([
            'qty' => ['sometimes', 'required', 'integer', 'min:0'],
            'active' => ['sometimes', 'nullable', 'boolean'],
        ]);

        $product->stocks()->updateExistingPivot($stock->id, $validated);

        return response()->json([
            'message' => 'Updated',
        ]);
    }

    public function detachFromProduct(Request $request, Product $product, Stock $stock)
    {
        $this->ensureAdmin($request);

        $exists = $product->stocks()
            ->where('stocks.id', $stock->id)
            ->exists();

        if (!$exists) {
            return response()->json([
                'message' => 'Stock belum terpasang di product ini',
            ], Response::HTTP_NOT_FOUND);
        }

        $product->stocks()->detach($stock->id);

        return response()->json([
            'message' => 'Detached',
        ]);
    }
}
