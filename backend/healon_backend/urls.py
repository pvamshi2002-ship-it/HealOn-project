from django.contrib import admin
from django.urls import include, path
from rest_framework.authtoken.views import obtain_auth_token

from people.views import AuthTokenView


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', AuthTokenView.as_view(), name='api-auth'),
    path('api/token-auth/', obtain_auth_token, name='token-auth'),
    path('api/', include('people.urls')),
]
