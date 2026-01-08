<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {

        User::updateOrCreate(
            ['email' => '3'],
            [
                'name' => 'Admin',
                'username' => 'admin',
                'password' => Hash::make('admin12345'),
                'pin_hash' => Hash::make('1234'),
                'role' => 'admin',
                'active' => true,
            ]
        );
    }
}
