"""Unit tests for payment request validation (AIDLC application layer)."""

import pytest

from validation import PaymentValidator, ValidationError


class TestTransactionId:
    def test_valid_id(self) -> None:
        ok, err = PaymentValidator.validate_transaction_id("TX-123_abc")
        assert ok is True
        assert err is None

    def test_empty_rejected(self) -> None:
        ok, err = PaymentValidator.validate_transaction_id("")
        assert ok is False
        assert err.field == "transaction_id"

    def test_sql_injection_rejected(self) -> None:
        ok, err = PaymentValidator.validate_transaction_id("'; DROP TABLE--")
        assert ok is False

    def test_xss_pattern_rejected(self) -> None:
        ok, err = PaymentValidator.validate_transaction_id("<script>alert(1)</script>")
        assert ok is False


class TestUserId:
    def test_valid_user(self) -> None:
        ok, err = PaymentValidator.validate_user_id("U100")
        assert ok is True

    def test_invalid_chars_rejected(self) -> None:
        ok, err = PaymentValidator.validate_user_id("user@evil")
        assert ok is False


class TestAmount:
    def test_valid_amount(self) -> None:
        ok, err = PaymentValidator.validate_amount(99.99)
        assert ok is True

    def test_below_minimum_rejected(self) -> None:
        ok, err = PaymentValidator.validate_amount(0)
        assert ok is False

    def test_above_maximum_rejected(self) -> None:
        ok, err = PaymentValidator.validate_amount(1_000_000_000)
        assert ok is False


class TestLocation:
    def test_valid_location(self) -> None:
        ok, err = PaymentValidator.validate_location("New Delhi, IN")
        assert ok is True

    def test_shell_metachar_rejected(self) -> None:
        ok, err = PaymentValidator.validate_location("Delhi; rm -rf /")
        assert ok is False


class TestValidateAll:
    def test_all_fields_valid(self) -> None:
        ok, errors = PaymentValidator.validate_all("TX1", "U1", 100.0, "Mumbai")
        assert ok is True
        assert errors == []

    def test_multiple_errors(self) -> None:
        ok, errors = PaymentValidator.validate_all("", "", -1, "")
        assert ok is False
        assert len(errors) >= 3
        assert all(isinstance(e, ValidationError) for e in errors)


class TestSanitize:
    def test_removes_control_chars(self) -> None:
        assert PaymentValidator.sanitize("hello\x00world") == "helloworld"
