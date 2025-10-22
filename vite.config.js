import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    server: {
        /*
        hmr: {
            host: "192.168.10.10",
        },
        cors: {
            origin: '*',
        },
        host: "192.168.10.10",
        */
        watch: {
            usePolling: true,
        },
    },
    plugins: [
        vue(),
        laravel({
            input: [
                'resources/js/app.js',
                'resources/js/countrySelect.min.js',
                //'resources/js/leaflet.js',
                'resources/css/app.css',
                'resources/css/countrySelect.min.css',
                //'resources/css/leaflet.css',
            ],
            refresh: true,
        }),
    ],
});
