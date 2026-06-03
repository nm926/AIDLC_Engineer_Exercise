"""
Input validation and sanitization for fraud detection requests.

Ensures all incoming data is validated, sanitized, and safe to process.
"""

import logging
import re
from typing import Optional, Tuple
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class ValidationError:
    """Validation error result."""
    field: str
    message: str
    code: str = "VALIDATION_ERROR"


class PaymentValidator:
    """Validates payment request data."""
    
    # Constraints
    MAX_TRANSACTION_ID_LENGTH = 100
    MAX_USER_ID_LENGTH = 50
    MAX_LOCATION_LENGTH = 100
    MIN_AMOUNT = 0.01
    MAX_AMOUNT = 999999999.99
    
    # Patterns
    TRANSACTION_ID_PATTERN = re.compile(r"^[A-Za-z0-9\-_]{1,100}$")
    USER_ID_PATTERN = re.compile(r"^[A-Za-z0-9_]{1,50}$")
    LOCATION_PATTERN = re.compile(r"^[A-Za-z\s,\-\.]{1,100}$")
    
    # Dangerous patterns
    INJECTION_PATTERNS = [
        r"(<|>|;|\||&)",  # Shell metacharacters
        r"(script|javascript|onclick)",  # XSS patterns
        r"(select|insert|update|delete|drop)",  # SQL patterns
    ]
    
    @classmethod
    def validate_transaction_id(cls, transaction_id: str) -> Tuple[bool, Optional[ValidationError]]:
        """
        Validate transaction ID.
        
        Args:
            transaction_id: Transaction identifier
            
        Returns:
            Tuple of (is_valid, error_if_invalid)
        """
        if not transaction_id:
            return False, ValidationError("transaction_id", "Transaction ID cannot be empty")
        
        if len(transaction_id) > cls.MAX_TRANSACTION_ID_LENGTH:
            return False, ValidationError(
                "transaction_id",
                f"Transaction ID too long (max {cls.MAX_TRANSACTION_ID_LENGTH} chars)"
            )
        
        if not cls.TRANSACTION_ID_PATTERN.match(transaction_id):
            return False, ValidationError(
                "transaction_id",
                "Transaction ID contains invalid characters (alphanumeric, dash, underscore only)"
            )
        
        # Check for injection attempts
        if cls._has_injection_pattern(transaction_id):
            logger.warning(f"Potential injection in transaction_id: {transaction_id}")
            return False, ValidationError(
                "transaction_id",
                "Transaction ID contains unsafe characters"
            )
        
        return True, None
    
    @classmethod
    def validate_user_id(cls, user_id: str) -> Tuple[bool, Optional[ValidationError]]:
        """
        Validate user ID.
        
        Args:
            user_id: User identifier
            
        Returns:
            Tuple of (is_valid, error_if_invalid)
        """
        if not user_id:
            return False, ValidationError("user_id", "User ID cannot be empty")
        
        if len(user_id) > cls.MAX_USER_ID_LENGTH:
            return False, ValidationError(
                "user_id",
                f"User ID too long (max {cls.MAX_USER_ID_LENGTH} chars)"
            )
        
        if not cls.USER_ID_PATTERN.match(user_id):
            return False, ValidationError(
                "user_id",
                "User ID contains invalid characters (alphanumeric, underscore only)"
            )
        
        return True, None
    
    @classmethod
    def validate_amount(cls, amount: float) -> Tuple[bool, Optional[ValidationError]]:
        """
        Validate payment amount.
        
        Args:
            amount: Payment amount
            
        Returns:
            Tuple of (is_valid, error_if_invalid)
        """
        if amount is None:
            return False, ValidationError("amount", "Amount cannot be None")
        
        if not isinstance(amount, (int, float)):
            return False, ValidationError("amount", "Amount must be a number")
        
        if amount < cls.MIN_AMOUNT:
            return False, ValidationError(
                "amount",
                f"Amount too small (minimum {cls.MIN_AMOUNT})"
            )
        
        if amount > cls.MAX_AMOUNT:
            return False, ValidationError(
                "amount",
                f"Amount too large (maximum {cls.MAX_AMOUNT})"
            )
        
        return True, None
    
    @classmethod
    def validate_location(cls, location: str) -> Tuple[bool, Optional[ValidationError]]:
        """
        Validate location string.
        
        Args:
            location: Location name
            
        Returns:
            Tuple of (is_valid, error_if_invalid)
        """
        if not location:
            return False, ValidationError("location", "Location cannot be empty")
        
        if len(location) > cls.MAX_LOCATION_LENGTH:
            return False, ValidationError(
                "location",
                f"Location too long (max {cls.MAX_LOCATION_LENGTH} chars)"
            )
        
        if not cls.LOCATION_PATTERN.match(location):
            return False, ValidationError(
                "location",
                "Location contains invalid characters (letters, spaces, hyphens, commas only)"
            )
        
        # Check for injection attempts
        if cls._has_injection_pattern(location):
            logger.warning(f"Potential injection in location: {location}")
            return False, ValidationError(
                "location",
                "Location contains unsafe characters"
            )
        
        return True, None
    
    @classmethod
    def validate_all(cls, transaction_id: str, user_id: str, amount: float, 
                    location: str) -> Tuple[bool, list]:
        """
        Validate all payment request fields.
        
        Args:
            transaction_id: Transaction identifier
            user_id: User identifier
            amount: Payment amount
            location: Location
            
        Returns:
            Tuple of (is_valid, list_of_errors)
        """
        errors = []
        
        # Validate each field
        valid, error = cls.validate_transaction_id(transaction_id)
        if not valid:
            errors.append(error)
        
        valid, error = cls.validate_user_id(user_id)
        if not valid:
            errors.append(error)
        
        valid, error = cls.validate_amount(amount)
        if not valid:
            errors.append(error)
        
        valid, error = cls.validate_location(location)
        if not valid:
            errors.append(error)
        
        return len(errors) == 0, errors
    
    @classmethod
    def _has_injection_pattern(cls, value: str) -> bool:
        """Check if value contains injection patterns."""
        lower_value = value.lower()
        for pattern in cls.INJECTION_PATTERNS:
            if re.search(pattern, lower_value, re.IGNORECASE):
                return True
        return False
    
    @classmethod
    def sanitize(cls, value: str) -> str:
        """
        Sanitize string by removing control characters.
        
        Args:
            value: String to sanitize
            
        Returns:
            Sanitized string
        """
        return "".join(c for c in value if ord(c) >= 32 or c in "\n\t\r")
