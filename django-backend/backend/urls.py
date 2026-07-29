"""
URL configuration for Essential Homes backend.
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from decouple import config

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
]

# Serve uploaded media files.
# NOTE: normally this route is DEBUG-only (nginx/a CDN serves media in real
# production), but this deployment doesn't have nginx in front of gunicorn
# yet, so gate on an explicit env var instead of DEBUG — without it, every
# uploaded photo 404s despite uploading "successfully" (no route served
# /media/ at all with DEBUG=False). Remove SERVE_MEDIA once nginx is set up
# to serve /media/ directly.
if settings.DEBUG or config('SERVE_MEDIA', default=False, cast=bool):
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
