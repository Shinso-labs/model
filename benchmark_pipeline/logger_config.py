"""Logging configuration for the benchmark pipeline."""

import logging
import sys
from pathlib import Path
from datetime import datetime


def setup_logging(log_level: str = "INFO", log_file: str = None) -> logging.Logger:
    """
    Configure logging for the benchmark pipeline.

    Args:
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Optional path to log file. If None, logs to console only.

    Returns:
        Configured logger instance
    """
    # Convert string log level to logging constant
    numeric_level = getattr(logging, log_level.upper(), logging.INFO)

    # Create logger
    logger = logging.getLogger("benchmark_pipeline")
    logger.setLevel(numeric_level)

    # Remove existing handlers to avoid duplicates
    logger.handlers.clear()

    # Create formatters
    detailed_formatter = logging.Formatter(
        fmt='%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    simple_formatter = logging.Formatter(
        fmt='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%H:%M:%S'
    )

    # Console handler (INFO and above)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(simple_formatter)
    logger.addHandler(console_handler)

    # File handler (DEBUG and above) - if log_file is specified
    if log_file:
        # Create log directory if it doesn't exist
        log_path = Path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)

        file_handler = logging.FileHandler(log_file, mode='a')
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(detailed_formatter)
        logger.addHandler(file_handler)

    # Debug handler (DEBUG only) - separate file for detailed debugging
    if numeric_level == logging.DEBUG and log_file:
        debug_log = log_file.replace('.log', '_debug.log')
        debug_handler = logging.FileHandler(debug_log, mode='a')
        debug_handler.setLevel(logging.DEBUG)
        debug_handler.setFormatter(detailed_formatter)
        logger.addHandler(debug_handler)

    logger.propagate = False

    return logger


def get_logger(name: str = None) -> logging.Logger:
    """
    Get a logger instance for a specific module.

    Args:
        name: Name of the module (e.g., 'api_client', 'evaluator')

    Returns:
        Logger instance
    """
    if name:
        return logging.getLogger(f"benchmark_pipeline.{name}")
    return logging.getLogger("benchmark_pipeline")


def get_default_log_file() -> str:
    """Get default log file path with timestamp."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_dir = Path(__file__).parent / "results" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    return str(log_dir / f"benchmark_{timestamp}.log")
