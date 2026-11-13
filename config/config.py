from dotenv import load_dotenv
import os

class Config:
    def __init__(self):
        load_dotenv()
        self.REDIS_URL = None
        self.GROQ_API_KEY = None

    def load_config(self):
        self.GROQ_API_KEY = os.getenv("GROQ_API_KEY")
        self.REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

    def get_redis_url(self):
        return self.REDIS_URL

    def get_groq_key(self):
        return self.GROQ_API_KEY

