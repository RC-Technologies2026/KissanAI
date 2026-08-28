import cloudinary
import os
from dotenv import load_dotenv

load_dotenv()

cloudinary_url = os.getenv("CLOUDINARY_URL")
if cloudinary_url:
    cloudinary.config(cloudinary_url=cloudinary_url)
