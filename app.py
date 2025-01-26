from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field
from fastapi.middleware.cors import CORSMiddleware
import asyncio
from typing import List, Dict
import json
import os
import time
import sys
from starlette.responses import JSONResponse
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class GameMath:
    GOLDEN_RATIO = 1.618034
    PRODUCTION_SCALING = 1.5
    COST_SCALING = 1.15
    
    @staticmethod
    def calculate_cost(base_cost: float, owned: int) -> float:
        return base_cost * (GameMath.COST_SCALING ** owned)
    
    @staticmethod
    def calculate_production(base_rate: float, count: int) -> float:
        return base_rate * count * GameMath.PRODUCTION_SCALING
    
    @staticmethod
    def calculate_time_to_next(current_rate: float, target_cost: int) -> float:
        return target_cost / max(current_rate, 1)

class Factory(BaseModel):
    cost: float
    production_rate: float
    level: int = 0

    def get_cost(self, owned: int) -> float:
        return GameMath.calculate_cost(self.cost, owned)
    
    def get_production(self, count: int) -> float:
        return GameMath.calculate_production(self.production_rate, count)

class GrandmaFactory(Factory):
    cost: float = 5.0
    production_rate: float = 0.5

class NursingHomeFactory(Factory):
    cost: float = 5.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 0.8

class GarageFactory(Factory):
    cost: float = 8.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 1.0

class SimpleFactory(Factory):
    cost: float = 13.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 1.5

class BasicFactory(Factory):
    cost: float = 21.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 2.0

class AdvancedFactory(Factory):
    cost: float = 34.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 3.0

class IndustrialPlantFactory(Factory):
    cost: float = 55.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 5.0

class PrintingFarmFactory(Factory):
    cost: float = 89.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 8.0

class UltraGrandmaFactory(Factory):
    cost: float = 144.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 12.0

class CookieGodFactory(Factory):
    cost: float = 233.0 * GameMath.GOLDEN_RATIO
    production_rate: float = 20.0

class State(BaseModel):
    cookie_count: float = 0
    click_value: float = 1
    upgrade_cost: float = 10
    factories: List[Dict[str, float]] = Field(default_factory=list)
    upgrades: Dict[str, int] = Field(default_factory=dict)
    last_click_time: float = 0
    click_count: int = 0
    click_times: List[float] = Field(default_factory=list)
    factory_costs: Dict[str, float] = Field(default_factory=lambda: {
        'grandma': 5.0,
        'nursing_home': 5.0 * GameMath.GOLDEN_RATIO,
        'garage': 8.0 * GameMath.GOLDEN_RATIO,
        'simple': 13.0 * GameMath.GOLDEN_RATIO,
        'basic': 21.0 * GameMath.GOLDEN_RATIO,
        'advanced': 34.0 * GameMath.GOLDEN_RATIO,
        'industrial': 55.0 * GameMath.GOLDEN_RATIO,
        'printing': 89.0 * GameMath.GOLDEN_RATIO,
        'ultra_grandma': 144.0 * GameMath.GOLDEN_RATIO,
        'cookie_god': 233.0 * GameMath.GOLDEN_RATIO
    })
    prestige_points: int = 0
    prestige_multiplier: float = 1
    total_cookies_produced: float = 0

    def calculate_upgrade_cost(self) -> float:
        upgrade_count = self.upgrades.get('upgrade', 0)
        return 10.0 * (2.0 + 0.2 * upgrade_count)

    def calculate_factory_cost(self, factory_type: str) -> float:
        factory_map = {
            'grandma': GrandmaFactory,
            'nursing_home': NursingHomeFactory,
            'garage': GarageFactory,
            'simple': SimpleFactory,
            'basic': BasicFactory,
            'advanced': AdvancedFactory,
            'industrial': IndustrialPlantFactory,
            'printing': PrintingFarmFactory,
            'ultra_grandma': UltraGrandmaFactory,
            'cookie_god': CookieGodFactory
        }
        factory = factory_map[factory_type]()
        count = sum(1 for f in self.factories if f['production_rate'] == factory.production_rate)
        return factory.get_cost(count)

    def update_click_rate(self):
        current_time = time.time()
        # Add current click
        self.click_times.append(current_time)
        # Remove clicks older than 1 second
        while self.click_times and current_time - self.click_times[0] > 1.0:
            self.click_times.pop(0)

    def total_production_rate(self) -> float:
        factory_rate = sum(
            f['production_rate']
            for f in self.factories
        )
        current_time = time.time()
        recent_clicks = len([t for t in self.click_times if current_time - t <= 1.0])
        click_rate = recent_clicks * self.click_value
        return (factory_rate + click_rate) * self.prestige_multiplier

    def calculate_prestige_bonus(self) -> float:
        return 1 + (self.prestige_points * 0.05)  # 5% more production per prestige point

    def prestige_threshold(self) -> float:
        base_threshold = 3000  # Base threshold
        scaling_factor = 1.5  # Growth factor
        return base_threshold * (scaling_factor ** self.prestige_points)

    def prestige(self):
        if self.cookie_count >= self.prestige_threshold():
            self.prestige_points += 1
            self.cookie_count = 0
            self.click_value = 1
            self.upgrade_cost = 10
            self.factories = []
            self.upgrades = {}
            self.last_click_time = 0
            self.click_count = 0
            self.click_times = []
            self.factory_costs = {
                'grandma': 5.0,
                'nursing_home': 5.0 * GameMath.GOLDEN_RATIO,
                'garage': 8.0 * GameMath.GOLDEN_RATIO,
                'simple': 13.0 * GameMath.GOLDEN_RATIO,
                'basic': 21.0 * GameMath.GOLDEN_RATIO,
                'advanced': 34.0 * GameMath.GOLDEN_RATIO,
                'industrial': 55.0 * GameMath.GOLDEN_RATIO,
                'printing': 89.0 * GameMath.GOLDEN_RATIO,
                'ultra_grandma': 144.0 * GameMath.GOLDEN_RATIO,
                'cookie_god': 233.0 * GameMath.GOLDEN_RATIO
            }
            self.total_cookies_produced = 0
            self.prestige_multiplier = self.calculate_prestige_bonus()

    def produce_cookies(self):
        factory_rate = sum(
            f['production_rate']
            for f in self.factories
        )
        self.cookie_count += factory_rate
        self.total_cookies_produced += factory_rate

    def click(self):
        self.cookie_count += self.click_value
        self.total_cookies_produced += self.click_value

state = State()

@app.get("/state")
def get_state():
    logger.info("Endpoint /state called")
    try:
        state_dict = state.dict()
        state_dict['total_production_rate'] = state.total_production_rate()
        state_dict['upgrade_cost'] = state.calculate_upgrade_cost()
        state_dict['prestige_points'] = state.prestige_points  # Add prestige points to the state
        state_dict['total_cookies_produced'] = state.total_cookies_produced  # Add total cookies produced
        state_dict['prestige_threshold'] = state.prestige_threshold()  # Add prestige threshold
        
        # Add factory counts to the state response
        factory_counts = {factory_type: 0 for factory_type in state.factory_costs.keys()}
        factory_map = {
            'grandma': GrandmaFactory,
            'nursing_home': NursingHomeFactory,
            'garage': GarageFactory,
            'simple': SimpleFactory,
            'basic': BasicFactory,
            'advanced': AdvancedFactory,
            'industrial': IndustrialPlantFactory,
            'printing': PrintingFarmFactory,
            'ultra_grandma': UltraGrandmaFactory,
            'cookie_god': CookieGodFactory
        }
        for factory in state.factories:
            for factory_type, factory_class in factory_map.items():
                if factory['production_rate'] == factory_class().production_rate:
                    factory_counts[factory_type] += 1
                    break
        state_dict['factory_counts'] = factory_counts
        
        return state_dict
    except Exception as e:
        logger.error(f"Error getting state: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/click")
def click():
    logger.info("Endpoint /click called")
    try:
        state.update_click_rate()
        state.click()
        return state
    except Exception as e:
        logger.error(f"Error clicking: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/upgrade")
def upgrade():
    logger.info("Endpoint /upgrade called")
    try:
        current_cost = state.calculate_upgrade_cost()
        if state.cookie_count >= current_cost:
            state.cookie_count -= current_cost
            state.click_value += 1
            state.upgrade_cost = state.calculate_upgrade_cost()
            state.upgrades['upgrade'] = state.upgrades.get('upgrade', 0) + 1
        return state
    except Exception as e:
        logger.error(f"Error upgrading: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/buy_factory/{factory_type}")
def buy_factory(factory_type: str):
    logger.info(f"Endpoint /buy_factory/{factory_type} called")
    try:
        factory_map = {
            'grandma': GrandmaFactory,
            'nursing_home': NursingHomeFactory,
            'garage': GarageFactory,
            'simple': SimpleFactory,
            'basic': BasicFactory,
            'advanced': AdvancedFactory,
            'industrial': IndustrialPlantFactory,
            'printing': PrintingFarmFactory,
            'ultra_grandma': UltraGrandmaFactory,
            'cookie_god': CookieGodFactory
        }
        
        if factory_type not in factory_map:
            raise HTTPException(status_code=400, detail="Invalid factory type")
            
        current_cost = state.calculate_factory_cost(factory_type)
        if state.cookie_count >= current_cost:
            state.cookie_count -= current_cost
            state.factories.append(factory_map[factory_type]().dict())
            state.factory_costs[factory_type] = state.calculate_factory_cost(factory_type)
        return state
    except Exception as e:
        logger.error(f"Error buying factory: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/reset_game")
def reset_game():
    logger.info("Endpoint /reset_game called")
    try:
        global state
        state = State()
        return state
    except Exception as e:
        logger.error(f"Error resetting game: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/save_game")
def save_game(slot: int = Query(1, ge=1, le=3)):
    logger.info(f"Endpoint /save_game called with slot {slot}")
    try:
        with open(f"game_state_{slot}.json", "w") as f:
            state_data = state.dict()
            state_data['factory_costs'] = {
                ftype: state.calculate_factory_cost(ftype)
                for ftype in state.factory_costs.keys()
            }
            state_data['total_cookies_produced'] = state.total_cookies_produced  # Ensure total_cookies_produced is saved
            json.dump(state_data, f)
        return {"message": f"Game state saved successfully in slot {slot}"}
    except Exception as e:
        logger.error(f"Error saving game: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/load_game")
def load_game(slot: int = Query(1, ge=1, le=3)):
    logger.info(f"Endpoint /load_game called with slot {slot}")
    try:
        global state
        if os.path.exists(f"game_state_{slot}.json"):
            with open(f"game_state_{slot}.json", "r") as f:
                state_data = json.load(f)
                state = State(**state_data)
                state.total_cookies_produced = state_data.get('total_cookies_produced', 0.0)  # Ensure total_cookies_produced is loaded
            return {"message": f"Game state loaded successfully from slot {slot}"}
        else:
            return {"message": f"No saved game state found in slot {slot}"}
    except Exception as e:
        logger.error(f"Error loading game: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/delete_game")
def delete_game(slot: int = Query(1, ge=1, le=3)):
    logger.info(f"Endpoint /delete_game called with slot {slot}")
    try:
        file_path = f"game_state_{slot}.json"
        if os.path.exists(file_path):
            os.remove(file_path)
            return {"message": f"Game state in slot {slot} deleted successfully"}
        else:
            return {"message": f"No saved game state found in slot {slot}"}
    except Exception as e:
        logger.error(f"Error deleting game: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/force_shutdown")
async def force_shutdown():
    logger.info("Endpoint /force_shutdown called")
    try:
        if cookie_production_task:
            cookie_production_task.cancel()
            try:
                await cookie_production_task
            except asyncio.CancelledError:
                pass

        async def shutdown_server():
            await asyncio.sleep(1)
            sys.exit(0)

        asyncio.create_task(shutdown_server())
        return JSONResponse({"message": "Server shutting down"})
    except Exception as e:
        logger.error(f"Error during shutdown: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/prestige")
def prestige():
    logger.info("Endpoint /prestige called")
    try:
        state.prestige()
        return state
    except Exception as e:
        logger.error(f"Error prestiging: {e}")
        raise HTTPException(status_code=500, detail=str(e))

cookie_production_task = None

@app.on_event("startup")
async def startup_event():
    logger.info("Server startup event")
    global cookie_production_task
    cookie_production_task = asyncio.create_task(produce_cookies())

async def produce_cookies():
    while True:
        try:
            state.produce_cookies()
            await asyncio.sleep(1)
        except Exception as e:
            logger.error(f"Error producing cookies: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Server shutdown event")

# Define the directory to store save files
SAVE_DIR = "saves"
os.makedirs(SAVE_DIR, exist_ok=True)

@app.get("/saves")
async def get_saves():
    saves = [int(f.split('.')[0]) for f in os.listdir(SAVE_DIR) if f.endswith('.json')]
    return saves

@app.post("/save_game")
async def save_game(slot: int):
    save_data = {
        "cookie_count": 100,  # Example data
        "click_value": 1,
        "total_production_rate": 0,
        "upgrade_cost": 10.0,
        "prestige_points": 0,
        "total_cookies_produced": 0.0,
        "factories": [],
        "factory_costs": {},
        "factory_counts": {},
    }
    with open(os.path.join(SAVE_DIR, f"{slot}.json"), "w") as f:
        json.dump(save_data, f)
    return {"message": "Game saved"}

@app.post("/load_game")
async def load_game(slot: int):
    try:
        with open(os.path.join(SAVE_DIR, f"{slot}.json"), "r") as f:
            save_data = json.load(f)
        return save_data
    except FileNotFoundError:
        return {"error": "Save not found"}, 404

@app.post("/delete_game")
async def delete_game(slot: int):
    try:
        os.remove(os.path.join(SAVE_DIR, f"{slot}.json"))
        return {"message": "Save deleted"}
    except FileNotFoundError:
        return {"error": "Save not found"}, 404

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)