<?php

namespace App\Http\Controllers\Product;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Stock;
use App\Models\ProductStock;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Database\QueryException;

class ProductController extends Controller
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
        $query = Product::query()
            ->with([
                'category:id,name',
                'stocks:id,name,unit,active',
            ])
            ->orderByDesc('id');

        if ($request->filled('search')) {
            $s = trim((string) $request->input('search'));
            $query->where('name', 'like', "%{$s}%");
        }

        if ($request->filled('category_id')) {
            $query->where('category_id', (int) $request->input('category_id'));
        }

        if ($request->has('active')) {
            $query->where('active', (bool) $request->boolean('active'));
        }

        $perPage = (int) $request->input('per_page', 15);
        $perPage = max(1, min($perPage, 100));

        return response()->json([
            'message' => 'OK',
            'data' => $query->paginate($perPage),
        ]);
    }

    public function show(Request $request, Product $product)
    {
        $product->load([
            'category:id,name',
            'stocks:id,name,unit,active',
        ]);

        return response()->json([
            'message' => 'OK',
            'data' => $product,
        ]);
    }

    public function store(Request $request)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'category_id' => ['required', 'integer', 'exists:product_categories,id'],
            'name' => ['required', 'string', 'max:120'],
            'price' => ['required', 'integer', 'min:0'],
            'qty' => ['nullable', 'integer', 'min:0'],
            'active' => ['nullable', 'boolean'],
        ]);

        $product = Product::create([
            'category_id' => (int) $validated['category_id'],
            'name' => $validated['name'],
            'price' => (int) $validated['price'],
            'qty' => (int) ($validated['qty'] ?? 0),
            'active' => (bool) ($validated['active'] ?? true),
        ]);

        return response()->json([
            'message' => 'Product created',
            'data' => $product->load(['category:id,name']),
        ], Response::HTTP_CREATED);
    }

    public function update(Request $request, Product $product)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'category_id' => ['sometimes', 'required', 'integer', 'exists:product_categories,id'],
            'name' => ['sometimes', 'required', 'string', 'max:120'],
            'price' => ['sometimes', 'required', 'integer', 'min:0'],
            'qty' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'active' => ['sometimes', 'nullable', 'boolean'],
        ]);

        $product->fill($validated);

        if (array_key_exists('qty', $validated) && $validated['qty'] === null) {
            $product->qty = 0;
        }

        $product->save();

        return response()->json([
            'message' => 'Product updated',
            'data' => $product->load(['category:id,name']),
        ]);
    }

    public function destroy(Request $request, Product $product)
    {
        $this->ensureAdmin($request);

        $product->delete();

        return response()->json([
            'message' => 'Product deleted',
        ]);
    }

    public function stocksMaster(Request $request)
    {
        $data = Stock::query()
            ->orderBy('name')
            ->get(['id', 'name', 'unit', 'active']);

        return response()->json([
            'message' => 'OK',
            'data' => $data,
        ]);
    }

    public function stocks(Request $request, Product $product)
    {
        $data = $product->stocks()
            ->orderBy('stocks.name')
            ->get()
            ->map(function ($s) {
                return [
                    'id' => $s->id,
                    'name' => $s->name,
                    'unit' => $s->unit,
                    'active' => $s->active,
                    'pivot' => [
                        'id' => $s->pivot->id ?? null,
                        'qty' => $s->pivot->qty ?? 0,
                        'active' => $s->pivot->active ?? true,
                    ],
                ];
            });

        return response()->json([
            'message' => 'OK',
            'data' => $data,
        ]);
    }

    public function attachStock(Request $request, Product $product)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'stock_id' => ['required', 'integer', 'exists:stocks,id'],
            'qty' => ['required', 'integer', 'min:0'],
            'active' => ['nullable', 'boolean'],
        ]);

        $row = ProductStock::updateOrCreate(
            [
                'product_id' => $product->id,
                'stock_id' => (int) $validated['stock_id'],
            ],
            [
                'qty' => (int) $validated['qty'],
                'active' => (bool) ($validated['active'] ?? true),
            ]
        );

        return response()->json([
            'message' => 'Stock attached',
            'data' => $row,
        ], Response::HTTP_OK);
    }

    public function updateStock(Request $request, Product $product, Stock $stock)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'qty' => ['sometimes', 'required', 'integer', 'min:0'],
            'active' => ['sometimes', 'nullable', 'boolean'],
        ]);

        $pivot = ProductStock::where('product_id', $product->id)
            ->where('stock_id', $stock->id)
            ->first();

        if (!$pivot) {
            return response()->json([
                'message' => 'Stock belum terpasang di product ini',
            ], Response::HTTP_NOT_FOUND);
        }

        if (array_key_exists('qty', $validated)) {
            $pivot->qty = (int) $validated['qty'];
        }

        if (array_key_exists('active', $validated)) {
            $pivot->active = (bool) ($validated['active'] ?? true);
        }

        $pivot->save();

        return response()->json([
            'message' => 'Product stock updated',
            'data' => $pivot,
        ], Response::HTTP_OK);
    }

    public function detachStock(Request $request, Product $product, Stock $stock)
    {
        $this->ensureAdmin($request);

        $deleted = ProductStock::where('product_id', $product->id)
            ->where('stock_id', $stock->id)
            ->delete();

        if (!$deleted) {
            return response()->json([
                'message' => 'Stock belum terpasang di product ini',
            ], Response::HTTP_NOT_FOUND);
        }

        return response()->json([
            'message' => 'Stock detached',
        ], Response::HTTP_OK);
    }
}
