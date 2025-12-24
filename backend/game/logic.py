from __future__ import annotations

import copy
import dataclasses
import hashlib
import re
from typing import Any


DEFAULT_WORLD_STATE = {
    "title": "Разрушенная Крепость",
    "scene": "Вы стоите перед разрушенной крепостью. Изнутри доносится далекий рев.",
    "location": "Внешние ворота",
    "threat": 1,
    "npcs": ["древний дракон"],
}


def _merge_dict(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = _merge_dict(merged[key], value)
        else:
            merged[key] = value
    return merged


def ensure_game_state(state: dict[str, Any] | None) -> dict[str, Any]:
    if not state or "version" not in state:
        legacy_world = state if isinstance(state, dict) else {}
        tools_cfg = (
            legacy_world.get("tools") if isinstance(legacy_world, dict) else None
        )
        world_seed = legacy_world
        if isinstance(legacy_world, dict) and isinstance(
            legacy_world.get("world"), dict
        ):
            world_seed = legacy_world.get("world", {})
        return {
            "version": 1,
            "world": _merge_dict(DEFAULT_WORLD_STATE, world_seed),
            "characters": {},
            "players": {},
            "turn": 0,
            "timeline": [],
            "llm_logs": [],
            **({"tools": tools_cfg} if tools_cfg is not None else {}),
        }

    normalized = copy.deepcopy(state)
    normalized.setdefault("world", {})
    normalized["world"] = _merge_dict(DEFAULT_WORLD_STATE, normalized["world"])
    normalized.setdefault("characters", {})
    normalized.setdefault("players", {})
    normalized.setdefault("turn", 0)
    normalized.setdefault("timeline", [])
    normalized.setdefault("llm_logs", [])
    return normalized


@dataclasses.dataclass
class CharacterProfile:
    name: str
    concept: str
    strength: int
    dexterity: int
    intelligence: int
    lore: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "concept": self.concept,
            "strength": self.strength,
            "dexterity": self.dexterity,
            "intelligence": self.intelligence,
            "lore": self.lore,
        }

    @staticmethod
    def from_dict(data: dict[str, Any]) -> "CharacterProfile":
        return CharacterProfile(
            name=data.get("name", "Безымянный"),
            concept=data.get("concept", "Странник"),
            strength=int(data.get("strength", 5)),
            dexterity=int(data.get("dexterity", 5)),
            intelligence=int(data.get("intelligence", 5)),
            lore=data.get("lore", ""),
        )


@dataclasses.dataclass
class CharacterQuestion:
    key: str
    prompt: str
    suggestions: list[str] = dataclasses.field(default_factory=list)


CHARACTER_QUESTIONS: list[CharacterQuestion] = [
    CharacterQuestion(
        key="name",
        prompt="Как зовут вашего персонажа?",
        suggestions=["Алира", "Торин", "Я предпочитаю оставаться безымянным"],
    ),
    CharacterQuestion(
        key="concept",
        prompt="Опишите его роль или архетип одним предложением.",
        suggestions=["Разведчик", "Ученый", "Наемник", "Маг-изгнанник"],
    ),
    CharacterQuestion(
        key="strength",
        prompt="Оцените силу (1-10) или опишите, насколько он силен.",
        suggestions=["Сила 8", "Сила 5", "Сила 3"],
    ),
    CharacterQuestion(
        key="dexterity",
        prompt="Оцените ловкость (1-10) или опишите, насколько он ловок.",
        suggestions=["Ловкость 8", "Ловкость 5", "Ловкость 3"],
    ),
    CharacterQuestion(
        key="intelligence",
        prompt="Оцените интеллект (1-10) или опишите, насколько он умен.",
        suggestions=["Интеллект 8", "Интеллект 5", "Интеллект 3"],
    ),
    CharacterQuestion(
        key="lore",
        prompt="Напишите краткую историю/предысторию персонажа.",
        suggestions=[
            "Бывший рыцарь, нарушивший клятву.",
            "Вырос среди контрабандистов на болотах.",
            "Ищет потерянного брата в руинах.",
        ],
    ),
]


@dataclasses.dataclass
class CharacterCreationSession:
    step: int = 0
    answers: dict[str, str] = dataclasses.field(default_factory=dict)
    completed: bool = False
    use_llm: bool = False
    messages: list[dict[str, str]] = dataclasses.field(default_factory=list)


@dataclasses.dataclass
class CharacterCreationResult:
    session: CharacterCreationSession
    next_question: CharacterQuestion | None = None
    character: CharacterProfile | None = None


def _clamp_stat(value: int) -> int:
    return max(1, min(10, value))


def _parse_stat_answer(text: str, fallback: int = 5) -> int:
    match = re.search(r"\b(\d{1,2})\b", text)
    if match:
        return _clamp_stat(int(match.group(1)))

    lowered = text.lower()
    if any(word in lowered for word in ("сильный", "мощный", "могучий", "крепкий")):
        return 8
    if any(word in lowered for word in ("слабый", "хрупкий", "неуклюжий")):
        return 3
    return fallback


def default_character_profile(player_name: str) -> CharacterProfile:
    return CharacterProfile(
        name=player_name or "Безымянный",
        concept="Странник",
        strength=5,
        dexterity=5,
        intelligence=5,
        lore="Неизвестный путник с тихим прошлым.",
    )


def build_character_from_answers(
    answers: dict[str, str], player_name: str
) -> CharacterProfile:
    return CharacterProfile(
        name=answers.get("name") or player_name or "Безымянный",
        concept=answers.get("concept", "Странник"),
        strength=_parse_stat_answer(answers.get("strength", "")),
        dexterity=_parse_stat_answer(answers.get("dexterity", "")),
        intelligence=_parse_stat_answer(answers.get("intelligence", "")),
        lore=answers.get("lore", "История, которая еще не написана."),
    )


def advance_character_session(
    session: CharacterCreationSession,
    answer_text: str,
    player_name: str,
) -> CharacterCreationResult:
    if session.completed:
        return CharacterCreationResult(session=session)

    if session.step < len(CHARACTER_QUESTIONS):
        question = CHARACTER_QUESTIONS[session.step]
        session.answers[question.key] = answer_text.strip()
        session.step += 1

    if session.step >= len(CHARACTER_QUESTIONS):
        session.completed = True
        character = build_character_from_answers(session.answers, player_name)
        return CharacterCreationResult(session=session, character=character)

    return CharacterCreationResult(
        session=session,
        next_question=CHARACTER_QUESTIONS[session.step],
    )


@dataclasses.dataclass
class PlayerAction:
    player_id: int
    player_name: str
    text: str
    character: CharacterProfile
    is_auto: bool = False


@dataclasses.dataclass
class ActionSummary:
    player_id: int
    player_name: str
    text: str
    stat_used: str
    roll: int
    target: int
    success: bool
    is_auto: bool

    def dm_summary(self) -> str:
        result = "преуспевает" if self.success else "терпит неудачу"
        return f'{self.player_name} пытается: "{self.text}" и {result}.'


@dataclasses.dataclass
class LLMLogEntry:
    scope: str
    model: str
    prompt: list[dict[str, Any]]
    response: str | dict[str, Any] | None
    player_id: int | None
    turn: int
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d = {
            "scope": self.scope,
            "model": self.model,
            "prompt": self.prompt,
            "response": self.response,
            "player_id": self.player_id,
            "turn": self.turn,
        }
        if self.error:
            d["error"] = self.error
        return d


@dataclasses.dataclass
class TurnResolution:
    world_state: dict[str, Any]
    summaries: list[ActionSummary]
    player_narratives: dict[int, str]
    turn_summary: str


STAT_KEYWORDS = {
    "strength": ("удар", "крушить", "поднять", "ломать", "толкать", "атака", "бить"),
    "dexterity": ("красться", "уклоняться", "стрелять", "красть", "прыгать", "взламывать"),
    "intelligence": ("анализ", "исследовать", "изучать", "заклинание", "план", "загадка"),
    "lore": ("помнить", "легенда", "история", "вспомнить", "миф"),
}


def _choose_stat(text: str, character: CharacterProfile) -> str:
    lowered = text.lower()
    scores = {key: 0 for key in STAT_KEYWORDS}
    for stat, keywords in STAT_KEYWORDS.items():
        for word in keywords:
            if word in lowered:
                scores[stat] += 1

    best = max(scores.items(), key=lambda kv: kv[1])[0]
    if scores[best] == 0:
        return max(
            ("strength", "dexterity", "intelligence"),
            key=lambda key: getattr(character, key),
        )
    return best


def _roll(seed: str) -> int:
    digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()
    return int(digest[:8], 16) % 20 + 1


def summarize_action(
    action: PlayerAction, world_state: dict[str, Any]
) -> ActionSummary:
    stat = _choose_stat(action.text, action.character)
    stat_value = getattr(action.character, stat, 5)
    threat = int(world_state.get("world", {}).get("threat", 0))
    target = 12 + max(0, threat)
    roll = _roll(f"{action.player_id}:{action.text}:{world_state.get('turn', 0)}")
    success = roll + stat_value >= target
    return ActionSummary(
        player_id=action.player_id,
        player_name=action.player_name,
        text=action.text,
        stat_used=stat,
        roll=roll,
        target=target,
        success=success,
        is_auto=action.is_auto,
    )


def _narrative_for_summary(summary: ActionSummary) -> str:
    if summary.success:
        return "Вы успокаиваете дыхание и действуете. Попытка оборачивается в вашу пользу."
    return "Вы двигаетесь, но попытка срывается. Опасность сжимает хватку."


def resolve_turn(
    summaries: list[ActionSummary],
    world_state: dict[str, Any],
) -> TurnResolution:
    successes = sum(1 for s in summaries if s.success)
    world = world_state.setdefault("world", {})
    threat = int(world.get("threat", 0))
    if summaries:
        if successes:
            threat = max(0, threat - 1)
        else:
            threat = min(5, threat + 1)
        world["threat"] = threat

    world_state["turn"] = int(world_state.get("turn", 0)) + 1
    turn_summary = " ".join(s.dm_summary() for s in summaries)
    timeline = world_state.setdefault("timeline", [])
    timeline.append({"turn": world_state["turn"], "summary": turn_summary})

    player_narratives = {
        s.player_id: f"Вы пытаетесь: {s.text}. {_narrative_for_summary(s)}"
        for s in summaries
    }
    return TurnResolution(
        world_state=world_state,
        summaries=summaries,
        player_narratives=player_narratives,
        turn_summary=turn_summary,
    )


def suggest_actions(
    world_state: dict[str, Any],
    character: CharacterProfile | None = None,
) -> list[str]:
    scene = world_state.get("world", {}).get("scene", "")
    suggestions = ["Осмотреться", "Прислушаться к угрозам", "Проверить на ловушки"]
    if "дракон" in scene.lower() or "dragon" in scene.lower():
        suggestions = [
            "Искать укрытие от дракона",
            "Искать слабое место",
            "Подготовить отвлекающий маневр",
        ]
    if character and character.dexterity >= 7:
        suggestions.append("Тихо разведать впереди")
    return suggestions[:3]


def build_advice_response(
    question: str,
    world_state: dict[str, Any],
    character: CharacterProfile | None = None,
) -> str:
    scene = world_state.get("world", {}).get("scene", "Сцена неясна.")
    highlight = ""
    if character:
        best_stat = max(
            ("strength", "dexterity", "intelligence"),
            key=lambda key: getattr(character, key),
        )
        stat_map = {
            "strength": "сила",
            "dexterity": "ловкость",
            "intelligence": "интеллект",
        }
        highlight = f"Ваша {stat_map.get(best_stat, best_stat)} выделяется. "
    return f"{highlight}Сцена: {scene} Ваш вопрос: {question}"
