<?php

namespace App\Services\Email;

class EmailTemplateRenderer
{
    public function render(?string $template, array $values): string
    {
        if ($template === null) {
            return '';
        }

        $replacements = [];
        foreach ($values as $key => $value) {
            $replacements['{{' . $key . '}}'] = $value;
        }

        return strtr($template, $replacements);
    }
}
