<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SaleTicketEntry extends Model
{
    use HasFactory;
    protected $fillable = [
        'sale_ticket_id',
        'secret',
        'seat_number',
        'scanned_at',
    ];

    protected $casts = [
        'scanned_at' => 'datetime',
    ];

    public function saleTicket()
    {
        return $this->belongsTo(SaleTicket::class);
    }

    // Support legacy attribute 'sale_id' used in some test helpers and seeds.
    public function setSaleIdAttribute($value)
    {
        try {
            $saleTicket = \App\Models\SaleTicket::where('sale_id', $value)->first();
            if ($saleTicket) {
                $this->attributes['sale_ticket_id'] = $saleTicket->id;
            }
        } catch (\Throwable $e) {
            // ignore if lookup fails
        }
    }

    public function getSaleIdAttribute()
    {
        return $this->saleTicket ? $this->saleTicket->sale_id : null;
    }
}
