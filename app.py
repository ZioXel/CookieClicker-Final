import logging
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field
from fastapi.middleware.cors import CORSMiddleware
import asyncio
from typing import List, Dict
import json
import os
import sys
from starlette.responses import JSONResponse

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

class Factory(BaseModel):
    cost: int
    production_rate: int

    def produce(self):
        return self.production_rate

class BasicFactory(Factory):
    cost: int = 10
    production_rate: int = 1

class AdvancedFactory(Factory):
    cost: int = 20
    production_rate: int = 2

class State(BaseModel):
    cookie_count: int = 0
    click_value: int = 1
    upgrade_cost: int = 10
    factories: List[Dict[str, int]] = Field(default_factory=list)
    upgrades: Dict[str, int] = Field(default_factory=dict)
    basic_factory_cost: int = 10
    advanced_factory_cost: int = 20

    def calculate_upgrade_cost(self) -> int:
        upgrade_count = self.upgrades.get('upgrade', 0)
        return int(10 * (2 + 0.2 * upgrade_count))

    def calculate_factory_cost(self, factory_type: str) -> int:
        count = sum(1 for f in self.factories 
                   if f['production_rate'] == (1 if factory_type == 'basic' else 2))
        base_cost = 10 if factory_type == 'basic' else 20
        return int(base_cost * (1 + 0.15 * count))

state = State()

@app.post("/buy_basic_factory")
def buy_basic_factory():
    try:
        current_cost = state.calculate_factory_cost('basic')
        if state.cookie_count >= current_cost:
            state.cookie_count -= current_cost
            state.factories.append(BasicFactory().dict())
            state.basic_factory_cost = state.calculate_factory_cost('basic')
        return state
    except Exception as e:
        logger.error(f"Error buying basic factory: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/buy_advanced_factory")
def buy_advanced_factory():
    try:
        current_cost = state.calculate_factory_cost('advanced')  # Use calculated cost
        if state.cookie_count >= current_cost:
            state.cookie_count -= current_cost
            state.factories.append(AdvancedFactory().dict())
            state.advanced_factory_cost = state.calculate_factory_cost('advanced')  # Update cost
        return state
    except Exception as e:
        logger.error(f"Error buying advanced factory: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/click")
def click():
    try:
        state.cookie_count += state.click_value
        return state
    except Exception as e:
        logger.error(f"Error clicking: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/upgrade")
def upgrade():
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

@app.post("/reset_game")
def reset_game():
    try:
        global state
        state = State()
        return state
    except Exception as e:
        logger.error(f"Error resetting game: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/save_game")
def save_game(slot: int = Query(1, ge=1, le=3)):
    try:
        with open(f"game_state_{slot}.json", "w") as f:
            state_data = state.dict()
            state_data['basic_factory_cost'] = state.calculate_factory_cost('basic')
            state_data['advanced_factory_cost'] = state.calculate_factory_cost('advanced')
            json.dump(state_data, f)
        return {"message": f"Game state saved successfully in slot {slot}"}
    except Exception as e:
        logger.error(f"Error saving game: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/load_game")
def load_game(slot: int = Query(1, ge=1, le=3)):
    try:
        global state
        if os.path.exists(f"game_state_{slot}.json"):
            with open(f"game_state_{slot}.json", "r") as f:
                state_data = json.load(f)
                state.cookie_count = state_data['cookie_count']
                state.click_value = state_data['click_value']
                state.upgrade_cost = state_data['upgrade_cost']
                state.factories = state_data['factories']
                state.upgrades = state_data['upgrades']
                # Load factory costs
                state.basic_factory_cost = state_data['basic_factory_cost']
                state.advanced_factory_cost = state_data['advanced_factory_cost']
            return {"message": f"Game state loaded successfully from slot {slot}"}
        else:
            return {"message": f"No saved game state found in slot {slot}"}
    except Exception as e:
        logger.error(f"Error loading game: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    
@app.post("/delete_game")
def delete_game(slot: int = Query(1, ge=1, le=3)):
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
    try:
        logger.info("Force shutdown initiated")
        
        # Cancel cookie production task
        if cookie_production_task:
            cookie_production_task.cancel()
            logger.info("Cookie production stopped")

        # Schedule immediate shutdown
        def exit_app():
            sys.exit(0)
            
        asyncio.get_event_loop().call_later(1, exit_app)
        
        return JSONResponse({"message": "Server shutting down"})
        
    except Exception as e:
        logger.error(f"Shutdown failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/start_server")
async def start_server():
    try:
        logger.info("Server startup initiated")

        # Initialize fresh game state
        global state, cookie_production_task
        state = State()
        logger.info("Fresh game state initialized")

        # Start cookie production if not running
        if cookie_production_task is None:
            cookie_production_task = asyncio.create_task(produce_cookies())
            logger.info("Cookie production started")

        return JSONResponse({
            "message": "Server started with fresh game",
            "status": "running"
        })

    except Exception as e:
        logger.error(f"Server startup failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def produce_cookies():
    while True:
        try:
            for factory in state.factories:
                state.cookie_count += factory['production_rate']
            await asyncio.sleep(1)  # Wait 1 second for update
        except Exception as e:
            logger.error(f"Error producing cookies: {e}")

# Add a global task reference
cookie_production_task = None

@app.on_event("startup")
async def startup_event():
    global cookie_production_task
    cookie_production_task = asyncio.create_task(produce_cookies())

@app.get("/state")
def get_state():
    try:
        return state
    except Exception as e:
        logger.error(f"Error getting state: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/shutdown")
async def shutdown():
    try:
        # Cancel cookie production task
        if cookie_production_task:
            cookie_production_task.cancel()
            try:
                await cookie_production_task
            except asyncio.CancelledError:
                pass

        # Schedule server shutdown
        async def shutdown_server():
            await asyncio.sleep(1)  # Brief delay to allow response to be sent
            sys.exit(0)  # Force exit the process

        asyncio.create_task(shutdown_server())
        return JSONResponse({"message": "Server shutting down"})
        
    except Exception as e:
        logger.error(f"Error during shutdown: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)