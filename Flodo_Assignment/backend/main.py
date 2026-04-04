from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, DateTime, ForeignKey, Enum as SQLEnum, func
from sqlalchemy.orm import sessionmaker, Session, declarative_base
from pydantic import BaseModel, field_validator
from typing import Optional, List
import datetime
import asyncio
import enum
import logging

# ==========================================
# 1. DATABASE INFRASTRUCTURE
# ==========================================
SQLALCHEMY_DATABASE_URL = "sqlite:///./tasks.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# ==========================================
# 2. PROFESSIONAL ENUMS
# ==========================================
class StatusEnum(str, enum.Enum):
    TODO = "To-Do"
    IN_PROGRESS = "In Progress"
    DONE = "Done"

class RecurringEnum(str, enum.Enum):
    NONE = "None"
    DAILY = "Daily"
    WEEKLY = "Weekly"
    MONTHLY = "Monthly"
    YEARLY = "Yearly"

# ==========================================
# 3. ENTERPRISE ORM MODEL
# ==========================================
class TaskDB(Base):
    __tablename__ = "tasks"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    description = Column(String, default="")
    due_date = Column(DateTime) 
    status = Column(SQLEnum(StatusEnum), default=StatusEnum.TODO)
    blocked_by_id = Column(Integer, ForeignKey("tasks.id"), nullable=True)
    recurring = Column(SQLEnum(RecurringEnum), default=RecurringEnum.NONE)
    sort_order = Column(Integer, default=0)
    task_type = Column(String, default="Work") 
    importance = Column(Integer, default=1) 
    extended_count = Column(Integer, default=0) # Tracks 24h pushes
    version = Column(Integer, default=1)        # Shadow Versioning for history

Base.metadata.create_all(bind=engine)

# ==========================================
# 4. SCHEMAS & UTC NORMALIZATION
# ==========================================
class TaskBase(BaseModel):
    title: str
    description: Optional[str] = ""
    due_date: datetime.datetime 
    status: StatusEnum = StatusEnum.TODO
    blocked_by_id: Optional[int] = None
    recurring: RecurringEnum = RecurringEnum.NONE
    sort_order: int = 0
    task_type: str = "Work"
    importance: int = 1

    @field_validator('due_date', mode='before')
    @classmethod
    def normalize_utc(cls, v):
        """Ensures all incoming deadlines are offset-naive UTC for DB safety."""
        if isinstance(v, str):
            v = datetime.datetime.fromisoformat(v.replace('Z', '+00:00'))
        return v.replace(tzinfo=None)

class TaskCreate(TaskBase):
    pass

class TaskResponse(TaskBase):
    id: int
    extended_count: int
    version: int
    class Config:
        from_attributes = True

# ==========================================
# 5. CORE ENGINE INITIALIZATION
# ==========================================
app = FastAPI(title="Flodo Enterprise Task Engine")

app.add_middleware(
    CORSMiddleware, 
    allow_origins=["*"], 
    allow_methods=["*"], 
    allow_headers=["*"]
)

@app.exception_handler(Exception)
async def system_fault_handler(request: Request, exc: Exception):
    """Intercepts internal crashes and provides professional telemetry."""
    logging.error(f"TELEMETRY FAULT: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={"detail": "System Fault: The workspace engine encountered an internal anomaly. Telemetry recorded."}
    )

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

# ==========================================
# 6. BUSINESS LOGIC UTILITIES
# ==========================================
def is_same_minute(dt1: datetime.datetime, dt2: datetime.datetime):
    return dt1.replace(second=0, microsecond=0) == dt2.replace(second=0, microsecond=0)

def check_circular_dependency(db: Session, task_id: int, new_parent_id: int) -> bool:
    """Recursively checks if setting a parent creates an infinite logic loop."""
    curr_id = new_parent_id
    while curr_id is not None:
        if curr_id == task_id: return True
        parent_task = db.query(TaskDB).filter(TaskDB.id == curr_id).first()
        curr_id = parent_task.blocked_by_id if parent_task else None
    return False

def cascade_time_shift(db: Session, parent_id: int, time_delta: datetime.timedelta):
    """Automatically pushes all downstream intent deadlines forward."""
    children = db.query(TaskDB).filter(TaskDB.blocked_by_id == parent_id).all()
    for child in children:
        child.due_date += time_delta
        child.version += 1
        cascade_time_shift(db, child.id, time_delta)

def get_deep_incomplete_descendants(task_id: int, db: Session):
    children = db.query(TaskDB).filter(TaskDB.blocked_by_id == task_id).all()
    for child in children:
        if child.status != StatusEnum.DONE: return True
        if get_deep_incomplete_descendants(child.id, db): return True
    return False

# ==========================================
# 7. API ENDPOINTS (WORKSPACE CONTROLLERS)
# ==========================================

@app.get("/analytics")
def get_dashboard_analytics(db: Session = Depends(get_db)):
    all_tasks = db.query(TaskDB).all()
    unique_count = db.query(func.count(func.distinct(TaskDB.title))).scalar()
    return {
        "todo": len([t for t in all_tasks if t.status == StatusEnum.TODO]),
        "in_progress": len([t for t in all_tasks if t.status == StatusEnum.IN_PROGRESS]),
        "done": len([t for t in all_tasks if t.status == StatusEnum.DONE]),
        "extended": len([t for t in all_tasks if t.extended_count > 0]),
        "unique_tasks": unique_count or 0
    }

@app.get("/tasks", response_model=List[TaskResponse])
def read_all_tasks(db: Session = Depends(get_db)):
    return db.query(TaskDB).order_by(TaskDB.sort_order.asc()).all()

@app.post("/tasks", response_model=TaskResponse)
async def create_task(task: TaskCreate, db: Session = Depends(get_db)):
    # 1. DUPLICATION GUARD
    if db.query(TaskDB).filter(func.lower(TaskDB.title) == task.title.lower().strip(), TaskDB.status != StatusEnum.DONE).first():
        raise HTTPException(status_code=400, detail="State Conflict: An active intent with this designation already exists.")

    # 2. CHRONOLOGY VAULT
    if task.blocked_by_id:
        parent = db.query(TaskDB).filter(TaskDB.id == task.blocked_by_id).first()
        if parent:
            if is_same_minute(parent.due_date, task.due_date):
                raise HTTPException(status_code=400, detail="Dependency Fault: Intent timeline cannot align with blocker.")
            if task.due_date < parent.due_date:
                raise HTTPException(status_code=400, detail="Dependency Fault: Dependent intent cannot precede blocker.")

    # 3. SINGLE ACTIVE TASK CONSTRAINT
    if task.status == StatusEnum.IN_PROGRESS and db.query(TaskDB).filter(TaskDB.status == StatusEnum.IN_PROGRESS).first():
        raise HTTPException(status_code=400, detail="State Conflict: Another intent is already active ('In Progress').")

    db_task = TaskDB(**task.model_dump())
    db_task.version = db.query(TaskDB).filter(TaskDB.title == task.title).count() + 1
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    return db_task

@app.put("/tasks/{task_id}", response_model=TaskResponse)
async def update_task(task_id: int, task: TaskCreate, db: Session = Depends(get_db)):
    db_task = db.query(TaskDB).filter(TaskDB.id == task_id).first()
    if not db_task: raise HTTPException(status_code=404, detail="Entity Fault: Not found.")

    # 1. CIRCULAR DEPENDENCY GUARD
    if task.blocked_by_id and check_circular_dependency(db, task_id, task.blocked_by_id):
        raise HTTPException(status_code=400, detail="Logic Fault: Circular dependency detected.")

    # 2. STATE MACHINE GUARD
    if task.status == StatusEnum.IN_PROGRESS:
        active = db.query(TaskDB).filter(TaskDB.status == StatusEnum.IN_PROGRESS, TaskDB.id != task_id).first()
        if active:
            raise HTTPException(status_code=400, detail=f"State Conflict: Intent {active.id} is maintaining focus.")

    # 3. CASCADE ENGINE: Check for time extension
    old_date = db_task.due_date
    new_date = task.due_date
    if new_date > old_date:
        cascade_time_shift(db, task_id, new_date - old_date)

    # 4. RECURRING GENERATOR
    was_not_done = db_task.status != StatusEnum.DONE
    for key, value in task.model_dump().items():
        setattr(db_task, key, value)
    
    db.commit()

    if was_not_done and task.status == StatusEnum.DONE and db_task.recurring != RecurringEnum.NONE:
        # Simplified Logic: Shift 1 day or 7 days
        days = 1 if db_task.recurring == RecurringEnum.DAILY else 7
        new_task = TaskDB(
            title=db_task.title, description=db_task.description,
            due_date=db_task.due_date + datetime.timedelta(days=days),
            status=StatusEnum.TODO, blocked_by_id=db_task.blocked_by_id,
            recurring=db_task.recurring, sort_order=db_task.sort_order + 1,
            task_type=db_task.task_type, importance=db_task.importance,
            version=db_task.version + 1
        )
        db.add(new_task)
        db.commit()

    db.refresh(db_task)
    return db_task

@app.put("/tasks/{task_id}/extend")
def extend_task(task_id: int, db: Session = Depends(get_db)):
    db_task = db.query(TaskDB).filter(TaskDB.id == task_id).first()
    if not db_task: raise HTTPException(status_code=404)
    
    delta = datetime.timedelta(hours=24)
    db_task.due_date += delta
    db_task.extended_count += 1
    db_task.version += 1
    
    cascade_time_shift(db, task_id, delta) # Auto-cascade the extension
    
    db.commit()
    db.refresh(db_task)
    return db_task

@app.delete("/tasks/{task_id}")
def delete_task(task_id: int, db: Session = Depends(get_db)):
    db_task = db.query(TaskDB).filter(TaskDB.id == task_id).first()
    if db_task.status != StatusEnum.DONE:
        raise HTTPException(status_code=400, detail="Purge Violation: Active intents cannot be purged.")
    
    if get_deep_incomplete_descendants(task_id, db):
        raise HTTPException(status_code=400, detail="Dependency Violation: Downstream intents remain incomplete.")

    db.delete(db_task)
    db.commit()
    return {"message": "State Sync: Intent purged successfully."}

@app.post("/tasks/reorder")
def reorder_tasks(ordered_ids: List[int], db: Session = Depends(get_db)):
    for index, tid in enumerate(ordered_ids):
        db.query(TaskDB).filter(TaskDB.id == tid).update({"sort_order": index})
    db.commit()
    return {"status": "Chronology reordered successfully."}