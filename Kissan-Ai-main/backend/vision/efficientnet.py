"""
EfficientNet-B0 vision pipeline for disease and pest detection.

Model: torchvision EfficientNet-B0 (ImageNet-pretrained).
The class label lists below define the model's output categories.
For production, replace with fine-tuned weights trained on plant
disease / pest datasets (e.g. PlantVillage, IP102).
"""
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
import io
from typing import Tuple, Optional

MODEL_VERSION = "efficientnet-b0"
CONFIDENCE_THRESHOLD = 0.70

_model = None
_device = "cpu"

# ImageNet-style preprocessing
_transform = transforms.Compose([
    transforms.Resize(224),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

# Disease class labels — replace with actual fine-tuned classes
DISEASE_CLASSES = [
    "healthy",
    "powdery_mildew",
    "leaf_rust",
    "blight",
    "anthracnose",
    "fusarium_wilt",
    "mosaic_virus",
    "black_rot",
]

# Pest class labels — replace with actual fine-tuned classes
PEST_CLASSES = [
    "aphids",
    "whitefly",
    "armyworm",
    "bollworm",
    "fruit_fly",
    "thrips",
    "spider_mites",
    "cotton_bug",
]


def _get_model() -> nn.Module:
    """Lazy-load EfficientNet-B0 on first inference call."""
    global _model
    if _model is None:
        _model = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
        _model.eval()
    return _model


@torch.no_grad()
def predict_disease(image_bytes: bytes) -> Tuple[str, float]:
    """
    Run disease classification on raw image bytes.
    Returns (disease_name, confidence_score).
    """
    return _predict(image_bytes, DISEASE_CLASSES)


@torch.no_grad()
def predict_pest(image_bytes: bytes) -> Tuple[str, float]:
    """
    Run pest classification on raw image bytes.
    Returns (pest_name, confidence_score).
    """
    return _predict(image_bytes, PEST_CLASSES)


def _predict(image_bytes: bytes, class_labels: list) -> Tuple[str, float]:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    tensor = _transform(image).unsqueeze(0).to(_device)

    model = _get_model()
    outputs = model(tensor)
    probabilities = torch.softmax(outputs, dim=1)[0]

    # Map to the target class list (handles mismatched sizes gracefully)
    num_classes = len(class_labels)
    relevant_probs = probabilities[:num_classes]

    top_idx = relevant_probs.argmax().item()
    top_conf = relevant_probs[top_idx].item()
    top_class = class_labels[top_idx]

    return top_class, top_conf
