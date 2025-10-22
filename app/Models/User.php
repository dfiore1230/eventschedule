<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Notifications\Notifiable;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Notifications\VerifyEmail as CustomVerifyEmail;

class User extends Authenticatable implements MustVerifyEmail
{
    use HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'timezone',
        'language_code',
        'profile_image_url',
        'api_key',
        'google_id',
        'google_token',
        'google_refresh_token',
        'google_token_expires_at',
        'facebook_id',
        'facebook_token',
        'facebook_token_expires_at',
        'stripe_account_id',
        'stripe_company_name',
        'stripe_completed_at',
        'invoiceninja_api_key',
        'invoiceninja_api_url',
        'invoiceninja_company_name',
        'invoiceninja_webhook_secret',
        'payment_url',
        'payment_secret',
        'is_subscribed',
        'profile_image_id',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'stripe_account_id',
        'invoiceninja_api_key',
        'invoiceninja_api_url',
        'invoiceninja_webhook_secret',
        'api_key',
        'payment_secret',
        'google_token',
        'google_refresh_token',
        'facebook_token',
    ];

    protected static function boot()
    {
        parent::boot();

        static::saving(function ($model) {
            $model->email = strtolower($model->email);
        });

        static::updating(function ($user) {
            if ($user->isDirty('email') && (config('app.hosted'))) {
                $user->email_verified_at = null;
                $user->sendEmailVerificationNotification();
            }
        });
    }
    
    public function sendEmailVerificationNotification()
    {
        // Only send verification email if user is subscribed
        if ($this->is_subscribed !== false) {
            $this->notify(new CustomVerifyEmail('user'));
        }
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'google_token_expires_at' => 'datetime',
            'facebook_token_expires_at' => 'datetime',
            'stripe_completed_at' => 'datetime',
            'is_subscribed' => 'boolean',
        ];
    }

    public function roles()
    {
        return $this->belongsToMany(Role::class)
                    ->withTimestamps()
                    ->withPivot('level')
                    ->where('is_deleted', false)
                    ->orderBy('name');
    }
    
    public function countRoles()
    {
        return count($this->roles()->get());
    }

    public function owner()
    {
        return $this->roles()->wherePivotIn('level', ['owner']);
    }

    public function member()
    {
        return $this->roles()->wherePivotIn('level', ['owner', 'admin']);
    }

    public function following()
    {
        return $this->roles()->wherePivot('level', 'follower');
    }

    public function profileImage(): BelongsTo
    {
        return $this->belongsTo(Image::class, 'profile_image_id');
    }

    public function venues()
    {
        return $this->member()->type('venue');
    }

    public function talents()
    {
        return $this->member()->type('talent');
    }

    public function curators()
    {
        return $this->member()->type('curator');
    }

    public function allCurators()
    {
        return $this->roles()
                    ->where('type', 'curator')
                    ->where(function($query) {
                        $query->whereIn('roles.id', function($subquery) {
                            $subquery->select('role_id')
                                    ->from('role_user')
                                    ->where('user_id', $this->id)
                                    ->whereIn('level', ['owner', 'admin']);
                        })
                        ->orWhere(function($q) {
                            $q->whereIn('roles.id', function($subquery) {
                                $subquery->select('role_id')
                                        ->from('role_user') 
                                        ->where('user_id', $this->id)
                                        ->where('level', 'follower');
                            })
                            ->where('accept_requests', true);
                        });
                    })
                    ->orderBy('name')
                    ->get();
    }

    public function tickets()
    {
        return $this->hasMany(Sale::class);
    }

    public function isMember($subdomain): bool
    {
        return $this->member()->where('subdomain', $subdomain)->exists();
    }

    public function isFollowing($subdomain): bool
    {
        return $this->following()->where('subdomain', $subdomain)->exists();
    }

    public function isConnected($subdomain): bool
    {
        return $this->roles()->where('subdomain', $subdomain)->exists();
    }

    public function paymentUrlHost()
    {
        $host = parse_url($this->payment_url, PHP_URL_HOST);

        $host = str_replace('www.', '', $host);

        return $host;
    }

    public function paymentUrlMobileOnly()
    {
        $host = $this->paymentUrlHost();

        $mobileOnly = [
            'venmo.com',
            'cash.app',
            'paytm.me',
            'phon.pe',
            'bitpay.co.il',
            'payboxapp.com',
            'qr.alipay.com',
            'tikkie.me',
        ];

        return in_array($host, $mobileOnly);
    }

    public function canEditEvent($event)
    {
        if ($this->id == $event->user_id) {
            return true;
        }

        foreach ($event->roles as $role) {
            if ($this->isMember($role->subdomain)) {
                return true;
            }
        }

        return false;
    }

    public function getProfileImageUrlAttribute($value)
    {
        if ($this->relationLoaded('profileImage') || $this->profile_image_id) {
            $url = optional($this->profileImage)->url();
            if ($url) {
                return $url;
            }
        }

        if (! $value) {
            return '';
        }

        return storage_asset_url($value);
    }

    public function isAdmin(): bool
    {
        if (config('app.debug')) {
            return true;
        } elseif (config('app.hosted')) {
            return in_array($this->id, [1, 26]);
        } else {
            return $this->id == 1;
        }
    }

    /**
     * Get the user's first name
     *
     * @return string
     */
    public function firstName(): string
    {
        if (!$this->name) {
            return 'there';
        }
        
        $nameParts = explode(' ', trim($this->name));
        return $nameParts[0] ?: 'there';
    }
}
