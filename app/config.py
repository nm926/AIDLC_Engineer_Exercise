"""
Configuration management for fraud detection service.

Handles environment-based settings with validation and safe defaults.
Supports local development, staging, and production environments.
"""

import logging
import os
from enum import Enum
from typing import Optional
from dataclasses import dataclass, field
from pathlib import Path

logger = logging.getLogger(__name__)


class Environment(str, Enum):
    """Application environment."""
    LOCAL = "local"
    STAGING = "staging"
    PRODUCTION = "production"


@dataclass
class OTELConfig:
    """OpenTelemetry configuration."""
    enabled: bool = True
    endpoint: str = "http://otel-collector-opentelemetry-collector.observability.svc.cluster.local:4317"
    protocol: str = "grpc"
    traces_exporter: str = "otlp"
    metrics_exporter: str = "none"
    logs_exporter: str = "none"
    service_name: str = "fraud-detection-service"
    
    @classmethod
    def from_env(cls) -> 'OTELConfig':
        """Create config from environment variables."""
        return cls(
            enabled=os.getenv("ENABLE_OTEL", "true").lower() == "true",
            endpoint=os.getenv(
                "OTEL_EXPORTER_OTLP_ENDPOINT",
                "http://otel-collector-opentelemetry-collector.observability.svc.cluster.local:4317"
            ),
            protocol=os.getenv("OTEL_EXPORTER_OTLP_PROTOCOL", "grpc"),
            traces_exporter=os.getenv("OTEL_TRACES_EXPORTER", "otlp"),
            service_name=os.getenv("OTEL_SERVICE_NAME", "fraud-detection-service"),
        )


@dataclass
class ServiceConfig:
    """Service configuration."""
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "INFO"
    environment: Environment = Environment.LOCAL
    
    # Fraud detection parameters
    high_value_threshold: float = 10000.0
    high_value_risk: float = 0.45
    location_mismatch_risk: float = 0.25
    rapid_transaction_risk: float = 0.2
    rapid_transaction_window_seconds: int = 20
    
    # Request handling
    request_timeout_seconds: float = 30.0
    max_retry_attempts: int = 3
    retry_backoff_seconds: float = 1.0
    
    # Health check
    health_check_timeout_seconds: float = 5.0
    
    # Feature flags
    enable_request_id_tracking: bool = True
    enable_structured_logging: bool = True
    
    @classmethod
    def from_env(cls) -> 'ServiceConfig':
        """Create config from environment variables with validation."""
        env_str = os.getenv("ENVIRONMENT", "local").lower()
        
        try:
            environment = Environment(env_str)
        except ValueError:
            logger.warning(f"Invalid environment '{env_str}', defaulting to local")
            environment = Environment.LOCAL
        
        # Adjust log level based on environment
        default_log_level = "DEBUG" if environment == Environment.LOCAL else "INFO"
        log_level = os.getenv("LOG_LEVEL", default_log_level).upper()
        
        config = cls(
            host=os.getenv("SERVICE_HOST", "0.0.0.0"),
            port=int(os.getenv("SERVICE_PORT", "8000")),
            log_level=log_level,
            environment=environment,
            high_value_threshold=float(os.getenv("FRAUD_HIGH_VALUE_THRESHOLD", "10000")),
            high_value_risk=float(os.getenv("FRAUD_HIGH_VALUE_RISK", "0.45")),
            location_mismatch_risk=float(os.getenv("FRAUD_LOCATION_RISK", "0.25")),
            rapid_transaction_risk=float(os.getenv("FRAUD_RAPID_RISK", "0.2")),
            rapid_transaction_window_seconds=int(os.getenv("FRAUD_WINDOW_SECONDS", "20")),
            enable_request_id_tracking=os.getenv("ENABLE_REQUEST_ID", "true").lower() == "true",
            enable_structured_logging=os.getenv("ENABLE_STRUCTURED_LOGGING", "true").lower() == "true",
        )
        
        # Validate configuration
        config._validate()
        return config
    
    def _validate(self) -> None:
        """Validate configuration values."""
        errors = []
        
        if self.port < 1 or self.port > 65535:
            errors.append(f"Invalid port: {self.port}")
        
        if self.high_value_threshold < 0:
            errors.append(f"Negative high_value_threshold: {self.high_value_threshold}")
        
        if not (0 <= self.high_value_risk <= 1.0):
            errors.append(f"Invalid risk score (must be 0-1): {self.high_value_risk}")
        
        if not (0 <= self.location_mismatch_risk <= 1.0):
            errors.append(f"Invalid risk score (must be 0-1): {self.location_mismatch_risk}")
        
        if self.rapid_transaction_window_seconds < 1:
            errors.append(f"Invalid window (must be >= 1): {self.rapid_transaction_window_seconds}")
        
        if errors:
            error_msg = "; ".join(errors)
            logger.error(f"Configuration validation failed: {error_msg}")
            raise ValueError(error_msg)
    
    def __str__(self) -> str:
        """Return configuration summary."""
        return (
            f"ServiceConfig(env={self.environment}, host={self.host}, port={self.port}, "
            f"log_level={self.log_level}, request_tracing={self.enable_request_id_tracking})"
        )


@dataclass
class ApplicationContext:
    """Application context holding all configurations."""
    service: ServiceConfig
    otel: OTELConfig
    start_time: float = field(default_factory=lambda: __import__('time').time())
    
    @classmethod
    def from_env(cls) -> 'ApplicationContext':
        """Create application context from environment."""
        service_config = ServiceConfig.from_env()
        otel_config = OTELConfig.from_env()
        
        logger.info(f"Application context initialized: {service_config}")
        logger.info(f"OpenTelemetry: {'enabled' if otel_config.enabled else 'disabled'}")
        
        return cls(service=service_config, otel=otel_config)
    
    def is_production(self) -> bool:
        """Check if running in production."""
        return self.service.environment == Environment.PRODUCTION
    
    def is_local(self) -> bool:
        """Check if running locally."""
        return self.service.environment == Environment.LOCAL


# Global configuration instance
_app_context: Optional[ApplicationContext] = None


def get_app_context() -> ApplicationContext:
    """Get or create the global application context."""
    global _app_context
    if _app_context is None:
        _app_context = ApplicationContext.from_env()
    return _app_context


def reset_app_context() -> None:
    """Reset global context (useful for testing)."""
    global _app_context
    _app_context = None
