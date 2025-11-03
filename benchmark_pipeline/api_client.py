"""API client for the Solidity to Move translation model."""

import requests
import time
import json
from typing import Optional, Dict, Any
from config import API_ROOT, API_KEY, MODEL_NAME, REQUEST_TIMEOUT, MAX_RETRIES, SYSTEM_PROMPT
from logger_config import get_logger

logger = get_logger('api_client')


class TranslationAPIClient:
    """Client for interacting with the Solidity to Move translation API."""

    def __init__(self, api_url: str = API_ROOT, api_key: str = API_KEY, model: str = MODEL_NAME):
        self.api_url = api_url
        self.api_key = api_key
        self.model = model
        self.session = requests.Session()
        self.session.headers.update({"Authorization": f"Bearer {self.api_key}"})

    def list_models(self, retry_count: int = 0) -> Optional[bool]:
        """
        Checks whether the ollama endpoint returns our configured model.

        Returns:
            True if the configured model is available, False otherwise
        """
        try:
            tags_url = self.api_url.replace('/api/generate', '/api/tags')
            logger.debug(f"Fetching models list from: {tags_url}")

            response = self.session.get(
                tags_url,
                timeout=REQUEST_TIMEOUT
            )

            logger.debug(f"List models response: status={response.status_code}")

            if response.status_code == 200:
                data = response.json()
                models = data.get('models', [])
                logger.debug(f"Received {len(models)} models from endpoint")

                # List is like [solmover:tag<latest>]
                model_names = [model.get('name', '').split(":")[0] for model in models]

                if self.model in model_names:
                    logger.info(f"✓ Model '{self.model}' is available")
                    logger.debug(f"Available models: {model_names}")
                    return True
                else:
                    logger.warning(f"✗ Model '{self.model}' not found. Available models: {model_names}")
                    return False
            else:
                logger.error(f"Failed to list models: Status {response.status_code}, Response: {response.text[:200]}")
                if retry_count < MAX_RETRIES:
                    logger.info(f"Retrying list_models... (attempt {retry_count + 1}/{MAX_RETRIES})")
                    time.sleep(2 ** retry_count)
                    return self.list_models(retry_count + 1)
                return False

        except Exception as e:
            logger.error(f"Error listing models: {e}", exc_info=True)
            if retry_count < MAX_RETRIES:
                logger.info(f"Retrying list_models after exception... (attempt {retry_count + 1}/{MAX_RETRIES})")
                time.sleep(2 ** retry_count)
                return self.list_models(retry_count + 1)
            return False


    def translate(self, solidity_code: str, retry_count: int = 0) -> Optional[Dict[str, Any]]:
        """
        Translate Solidity code to Sui Move.

        Args:
            solidity_code: The Solidity source code to translate
            retry_count: Current retry attempt number

        Returns:
            Dictionary with translation results including generated code and metadata,
            or None if translation failed
        """
        try:
            payload = {
                "model": self.model,
                "prompt": solidity_code,
                "system": SYSTEM_PROMPT,
                "stream": True
            }

            logger.debug(f"Preparing translation request - code length: {len(solidity_code)} chars")
            logger.debug(f"Using model: {self.model}, endpoint: {self.api_url}")

            start_time = time.time()
            logger.info("Sending request to translation endpoint...")
            response = self.session.post(
                self.api_url,
                json=payload,
                timeout=REQUEST_TIMEOUT,
                stream=True  # Enable streaming
            )
            logger.info(f"API responded with status: {response.status_code}")

            if response.status_code == 200:
                # Parse streaming response (newline-delimited JSON)
                logger.info("Processing streaming response...")
                generated_code = ""
                chunk_count = 0

                for line in response.iter_lines():
                    if line:
                        try:
                            chunk = json.loads(line.decode('utf-8'))
                            token = chunk.get("response", "")
                            generated_code += token
                            chunk_count += 1

                            if chunk_count % 50 == 0:
                                logger.debug(f"Processed {chunk_count} chunks, generated {len(generated_code)} chars")

                            if chunk.get("done", False):
                                logger.debug(f"Stream complete after {chunk_count} chunks")
                                break
                        except json.JSONDecodeError as e:
                            logger.warning(f"Failed to parse streaming chunk: {line[:100]}... Error: {e}")
                            continue

                end_time = time.time()
                response_time = end_time - start_time

                logger.info(f"Translation completed in {response_time:.2f}s")
                logger.debug(f"Generated code length: {len(generated_code)} chars")

                cleaned_code = self._clean_generated_code(generated_code)
                logger.debug(f"Cleaned code length: {len(cleaned_code)} chars")

                return {
                    "success": True,
                    "generated_code": cleaned_code,
                    "raw_generated_code": generated_code,
                    "response_time": response_time,
                    "status_code": response.status_code,
                    "raw_response": {"response": generated_code}
                }
            else:
                end_time = time.time()
                error_message = f"API returned status code {response.status_code}: {response.text}"
                logger.error(f"Translation failed: {error_message}")

                if response.status_code >= 500 and retry_count < MAX_RETRIES:
                    logger.info(f"Retrying translation... (attempt {retry_count + 1}/{MAX_RETRIES})")
                    time.sleep(2 ** retry_count)  # Exponential backoff
                    return self.translate(solidity_code, retry_count + 1)

                return {
                    "success": False,
                    "error": error_message,
                    "status_code": response.status_code,
                    "response_time": end_time - start_time
                }

        except requests.exceptions.Timeout:
            error_message = f"Request timed out after {REQUEST_TIMEOUT} seconds"
            logger.error(error_message)

            if retry_count < MAX_RETRIES:
                logger.info(f"Retrying translation after timeout... (attempt {retry_count + 1}/{MAX_RETRIES})")
                time.sleep(2 ** retry_count)
                return self.translate(solidity_code, retry_count + 1)

            return {
                "success": False,
                "error": error_message,
                "response_time": REQUEST_TIMEOUT
            }

        except Exception as e:
            error_message = f"Unexpected error: {str(e)}"
            logger.error(f"Translation failed with unexpected error: {error_message}", exc_info=True)
            return {
                "success": False,
                "error": error_message,
                "response_time": 0
            }

    def _clean_generated_code(self, code: str) -> str:
        """
        Clean unwanted tokens and artifacts from generated code.

        Args:
            code: Raw generated code from the model

        Returns:
            Cleaned code
        """
        if not code:
            logger.debug("Empty code provided for cleaning")
            return code

        original_length = len(code)

        unwanted_tokens = [
            "<|endoftext|>",
            "<|end|>",
            "<|start|>",
            "```move",
            "```",
            "<dyad-write",
            "</dyad-write>",
        ]

        cleaned = code
        removed_tokens = []
        for token in unwanted_tokens:
            if token in cleaned:
                removed_tokens.append(token)
                cleaned = cleaned.replace(token, "")

        cleaned = cleaned.strip()

        if removed_tokens:
            logger.debug(f"Removed unwanted tokens: {removed_tokens}")
        logger.debug(f"Code cleaning: {original_length} -> {len(cleaned)} chars")

        return cleaned

    def test_connection(self) -> bool:
        """
        Test if the API is accessible and the configured model is available.

        Returns:
            True if connection is successful and model is available, False otherwise
        """
        try:
            logger.info(f"Testing connection to {self.api_url}...")
            result = self.list_models()
            if result:
                logger.info("✓ Connection test successful")
            else:
                logger.error("✗ Connection test failed: Model not available")
            return result
        except Exception as e:
            logger.error(f"✗ Connection test failed: {e}", exc_info=True)
            return False
