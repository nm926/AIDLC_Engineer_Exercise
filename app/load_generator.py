"""
Generates continuous dummy traffic to the fraud-detection service.
This script sends realistic payment requests to generate metrics, logs, and traces.
"""
import argparse
import logging
import os
import random
import time
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("load-generator")

# Configuration
REQUEST_INTERVAL = 2  # seconds between requests
BATCH_SIZE = 5  # requests per batch

# Test data
USERS = ["U100", "U101", "U102", "U103", "U104"]
LOCATIONS = ["Mumbai", "Delhi", "Bengaluru", "Hyderabad", "Pune", "Chennai"]
AMOUNTS = [100, 500, 1500, 5000, 12000, 15000, 25000]
TRANSACTION_COUNTER = 0
SERVICE_URL = os.getenv("SERVICE_URL", "http://127.0.0.1:8000").rstrip("/")


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Generate fraud-service load")
    parser.add_argument(
        "--service-url",
        default=None,
        help="Override the fraud service base URL (for example, http://127.0.0.1:8000)",
    )
    return parser.parse_args()


def generate_request() -> dict:
    """Generate a realistic payment request."""
    global TRANSACTION_COUNTER
    TRANSACTION_COUNTER += 1
    
    user = random.choice(USERS)
    amount = random.choice(AMOUNTS)
    location = random.choice(LOCATIONS)
    
    return {
        "transaction_id": f"TX-{TRANSACTION_COUNTER:06d}",
        "user_id": user,
        "amount": amount,
        "location": location,
    }


def send_request(service_url: str, payload: dict) -> bool:
    """Send a single payment check request."""
    try:
        response = requests.post(
            f"{service_url}/check-payment",
            json=payload,
            timeout=5
        )
        if response.status_code == 200:
            result = response.json()
            logger.info(
                f"✓ TX:{payload['transaction_id']} User:{payload['user_id']} "
                f"Amount:{payload['amount']} Fraud:{result['fraud_detected']} "
                f"Score:{result['risk_score']}"
            )
            return True
        else:
            logger.warning(f"✗ Request failed with status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        logger.error(f"✗ Request error: {e}")
        return False


def healthcheck(service_url: str) -> bool:
    """Check if service is healthy."""
    try:
        response = requests.get(
            f"{service_url}/api/health",
            timeout=5
        )
        return response.status_code == 200
    except requests.exceptions.RequestException:
        return False


def main():
    """Main load generator loop."""
    args = parse_args()
    service_url = (args.service_url or SERVICE_URL).rstrip("/")

    logger.info("🚀 Starting load generator...")
    logger.info(f"📍 Target: {service_url}")
    
    # Wait for service to be ready
    max_retries = 30
    for attempt in range(max_retries):
        if healthcheck(service_url):
            logger.info("✓ Service is healthy, starting load generation")
            break
        logger.info(f"⏳ Waiting for service ({attempt + 1}/{max_retries})...")
        time.sleep(2)
    else:
        logger.error("✗ Service did not become healthy in time")
        return
    
    logger.info(f"📊 Generating {BATCH_SIZE} requests every {REQUEST_INTERVAL} seconds...")
    
    try:
        while True:
            for _ in range(BATCH_SIZE):
                payload = generate_request()
                send_request(service_url, payload)
                time.sleep(REQUEST_INTERVAL / BATCH_SIZE)
            
            time.sleep(REQUEST_INTERVAL)
    except KeyboardInterrupt:
        logger.info("\n⏹️  Load generator stopped")


if __name__ == "__main__":
    main()
