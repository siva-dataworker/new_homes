"""
URL configuration for Essential Homes backend.
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.views.static import serve
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
#
# IMPORTANT: django.conf.urls.static.static() is NOT used here on purpose —
# it has a hardcoded internal check that makes it a silent no-op whenever
# settings.DEBUG is False, regardless of any condition wrapped around the
# call to it. Registering the underlying view directly avoids that guard.
if settings.DEBUG or config('SERVE_MEDIA', default=False, cast=bool):
    urlpatterns += [
        path('media/<path:path>', serve, {'document_root': settings.MEDIA_ROOT}),
    ]
