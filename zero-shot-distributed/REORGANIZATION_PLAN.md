# Code-Scripts目录重组方案

## 📁 **建议的新目录结构**

```
code-scripts/
├── core/                           # 核心功能脚本
│   ├── distributed_coordinator.sh      # 分布式协调器 (主入口)
│   ├── run_zeroshot_classification.sh  # 单任务执行器
│   └── run_zeroshot_batch.sh          # 批量任务执行器
│
├── setup/                          # 环境设置相关
│   ├── start_distributed_setup.sh     # 总体搭建向导 (主入口)
│   ├── setup_distributed_wrapper.sh   # 环境设置封装器
│   ├── setup_distributed_environment.sh  # 环境配置脚本
│   ├── quick_setup_distributed.sh     # 快速设置脚本
│   ├── enable_single_gpu_mode.sh      # 单GPU模式切换
│   └── restore_multi_gpu_mode.sh      # 多GPU模式恢复
│
├── data-management/                # 数据和模型管理
│   ├── smart_data_distributor.sh      # 数据分发器
│   ├── distilled_model_distributor.sh # 模型分发器
│   └── sync_datasets.sh              # 数据集同步
│
├── testing/                        # 测试相关
│   ├── single_gpu_quick_test.sh       # 单GPU快速测试
│   └── smart_distributed_train.sh     # 智能分布式训练测试
│
├── utils/                          # 工具和监控
│   ├── monitor_distributed.sh         # 分布式监控
│   └── dynamic_gpu_config.env        # GPU配置文件
│
└── README.md                       # 脚本使用指南
```

## 🔄 **脚本功能分类**

### 1. **Core (核心功能) - 3个脚本**
- `distributed_coordinator.sh` - 分布式任务协调器 ⭐ **主要入口**
- `run_zeroshot_classification.sh` - 单任务执行器 ⭐ **核心功能**  
- `run_zeroshot_batch.sh` - 批量执行器

### 2. **Setup (环境设置) - 6个脚本**
- `start_distributed_setup.sh` - 总体设置向导 ⭐ **主要入口**
- `setup_distributed_wrapper.sh` - 环境设置封装器
- `setup_distributed_environment.sh` - 环境配置
- `quick_setup_distributed.sh` - 快速设置
- `enable_single_gpu_mode.sh` - 单GPU模式
- `restore_multi_gpu_mode.sh` - 多GPU模式

### 3. **Data-Management (数据管理) - 3个脚本**
- `smart_data_distributor.sh` - 数据分发器
- `distilled_model_distributor.sh` - 模型分发器  
- `sync_datasets.sh` - 数据同步

### 4. **Testing (测试功能) - 2个脚本**
- `single_gpu_quick_test.sh` - 快速测试
- `smart_distributed_train.sh` - 分布式训练测试

### 5. **Utils (工具监控) - 2个文件**
- `monitor_distributed.sh` - 监控工具
- `dynamic_gpu_config.env` - GPU配置

## 🚀 **用户使用流程**

### **首次部署流程**
```bash
# 1. 环境设置
./setup/start_distributed_setup.sh

# 2. 数据分发  
./data-management/smart_data_distributor.sh
./data-management/distilled_model_distributor.sh

# 3. 快速测试
./testing/single_gpu_quick_test.sh

# 4. 启动分布式测试
./core/distributed_coordinator.sh
```

### **日常使用流程**
```bash
# 单任务测试
./core/run_zeroshot_classification.sh

# 批量任务
./core/run_zeroshot_batch.sh  

# 监控状态
./utils/monitor_distributed.sh
```

## 🔧 **迁移计划**

### **Step 1: 创建新目录结构**
```bash
mkdir -p code-scripts/{core,setup,data-management,testing,utils}
```

### **Step 2: 移动脚本到对应目录**
```bash
# Core scripts
mv distributed_coordinator.sh core/
mv run_zeroshot_classification.sh core/
mv run_zeroshot_batch.sh core/

# Setup scripts  
mv start_distributed_setup.sh setup/
mv setup_distributed_wrapper.sh setup/
mv setup_distributed_environment.sh setup/
mv quick_setup_distributed.sh setup/
mv enable_single_gpu_mode.sh setup/
mv restore_multi_gpu_mode.sh setup/

# Data management
mv smart_data_distributor.sh data-management/
mv distilled_model_distributor.sh data-management/
mv sync_datasets.sh data-management/

# Testing
mv single_gpu_quick_test.sh testing/
mv smart_distributed_train.sh testing/

# Utils
mv monitor_distributed.sh utils/
mv dynamic_gpu_config.env utils/
```

### **Step 3: 更新指南文档**
更新`零样本图像分类指南.md`中的脚本路径：
```bash
# 旧路径
./distributed_coordinator.sh

# 新路径  
./code-scripts/core/distributed_coordinator.sh
```

### **Step 4: 创建便捷入口脚本**
在项目根目录创建常用脚本的快捷入口：
```bash
# create_shortcuts.sh
#!/bin/bash
ln -sf code-scripts/core/distributed_coordinator.sh ./distributed_coordinator.sh
ln -sf code-scripts/setup/start_distributed_setup.sh ./start_distributed_setup.sh
ln -sf code-scripts/core/run_zeroshot_classification.sh ./run_zeroshot_classification.sh
```

## 📋 **重组后的优势**

1. **功能清晰**: 按功能分类，易于理解和维护
2. **层次分明**: 核心功能突出，支持工具分离
3. **易于扩展**: 新脚本可按功能归类添加
4. **用户友好**: 主要入口脚本在core和setup目录
5. **版本管理**: 便于追踪不同类型脚本的变更

## ⚠️ **注意事项**

1. **脚本间依赖**: 移动前检查脚本间的相对路径引用
2. **符号链接**: 考虑为常用脚本创建根目录的符号链接
3. **文档更新**: 同步更新所有相关文档中的路径
4. **测试验证**: 重组后进行完整的功能测试

## 🎯 **推荐操作**

建议按以下顺序执行：
1. 先创建新目录结构
2. 复制（而非移动）脚本到新位置
3. 测试新结构的功能完整性
4. 更新文档和引用
5. 确认无误后删除旧的扁平结构 