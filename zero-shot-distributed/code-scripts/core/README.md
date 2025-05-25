# Core Scripts - 核心功能脚本

这个目录包含系统的核心功能脚本，是用户最常使用的主要入口。

## 脚本说明

- **distributed_coordinator.sh** - 分布式任务协调器
  - 功能：自动任务分配和调度、进度监控、结果收集
  - 用法：`./distributed_coordinator.sh`
  
- **run_zeroshot_classification.sh** - 单任务执行器
  - 功能：执行单个数据集+模型组合的零样本分类
  - 用法：`./run_zeroshot_classification.sh <数据集> <模型> [参数...]`
  
- **run_zeroshot_batch.sh** - 批量任务执行器
  - 功能：批量执行多个零样本分类任务
  - 用法：`./run_zeroshot_batch.sh`

## 使用建议

1. 首次使用请先运行 `../setup/start_distributed_setup.sh` 进行环境配置
2. 单个任务测试使用 `run_zeroshot_classification.sh`
3. 大规模分布式测试使用 `distributed_coordinator.sh`
