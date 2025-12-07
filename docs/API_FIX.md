# API 修复说明

## 问题描述

在测试微服务 API 时遇到错误：
```
{"detail":[{"type":"missing","loc":["query","email"],"msg":"Field required"}]}
```

## 问题原因

FastAPI 中，如果函数参数没有使用 Pydantic 模型或 `Body()` 装饰器，这些参数会被视为**查询参数**（query parameters），而不是**请求体**（request body）。

**错误的代码：**
```python
@app.post("/api/users")
async def create_user(email: str, name: str, password: str, db: Session = Depends(get_db)):
    # FastAPI 会将 email, name, password 视为查询参数
    # 请求应该是: POST /api/users?email=xxx&name=xxx&password=xxx
    # 而不是: POST /api/users with JSON body
```

## 解决方案

使用 **Pydantic 模型**来定义请求体：

**正确的代码：**
```python
from pydantic import BaseModel

class UserCreate(BaseModel):
    """创建用户的请求模型"""
    email: str
    name: str
    password: str

@app.post("/api/users")
async def create_user(user_data: UserCreate, db: Session = Depends(get_db)):
    # FastAPI 会自动从请求体中解析 JSON 数据
    # 请求应该是: POST /api/users with JSON body {"email": "...", "name": "...", "password": "..."}
    user = User(email=user_data.email, name=user_data.name, password=user_data.password)
    ...
```

## 为什么使用 Pydantic 模型？

1. **数据验证**：自动验证请求体数据格式和类型
2. **类型安全**：提供类型提示和自动文档生成
3. **序列化**：自动处理 JSON 序列化/反序列化
4. **API 文档**：自动生成 Swagger/OpenAPI 文档

## 已修复的服务

### 1. User Service (`services/user-service/main.py`)
- 添加 `UserCreate` 模型
- 修改 `create_user` 函数使用模型

### 2. Product Service (`services/product-service/main.py`)
- 添加 `ProductCreate` 模型
- 修改 `create_product` 函数使用模型

### 3. Order Service (`services/order-service/main.py`)
- 添加 `OrderCreate` 模型
- 修改 `create_order` 函数使用模型

## 重新部署

修复后需要重新构建 Docker 镜像：

```powershell
# 重新构建镜像
.\scripts\build-images.ps1

# 重新部署（如果需要）
kubectl rollout restart deployment -n microservices user-service
kubectl rollout restart deployment -n microservices product-service
kubectl rollout restart deployment -n microservices order-service
```

## 测试 API

修复后，可以使用以下命令测试：

```powershell
# 创建用户
Invoke-RestMethod -Uri "http://localhost:8001/api/users" -Method POST -ContentType "application/json" -Body '{"email":"test@example.com","name":"Test User","password":"123456"}'

# 创建商品
Invoke-RestMethod -Uri "http://localhost:8002/api/products/" -Method POST -ContentType "application/json" -Body '{"name":"MacBook Pro","description":"Laptop","price":12999.0,"stock":50}'

# 创建订单
Invoke-RestMethod -Uri "http://localhost:8003/api/orders" -Method POST -ContentType "application/json" -Body '{"user_id":1,"product_id":1,"quantity":1}'
```

## 学习要点

1. **FastAPI 参数类型**：
   - 路径参数：`@app.get("/api/users/{user_id}")` → `user_id: int`
   - 查询参数：`@app.get("/api/users")` → `skip: int = 0`
   - 请求体：`@app.post("/api/users")` → `user_data: UserCreate`（Pydantic 模型）

2. **Pydantic 的优势**：
   - 自动数据验证
   - 类型转换
   - 错误消息清晰
   - 自动生成 API 文档

3. **最佳实践**：
   - 总是使用 Pydantic 模型定义请求体
   - 为每个 API 端点创建专门的模型
   - 使用模型验证确保数据完整性










