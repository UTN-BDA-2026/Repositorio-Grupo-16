from pydantic import BaseModel


class Recommendation(BaseModel):
    user_id: int
    nombre: str
    email: str
    compatibilidad: float
    intereses_compartidos: list[str]


class RecommendationRequest(BaseModel):
    user_id: int
    limite: int = 5
