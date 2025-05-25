# Setup Scripts - 环境设置脚本

这个目录包含系统环境配置和设置相关的脚本。

## 脚本说明

- **start_distributed_setup.sh** - 总体搭建向导 (主入口)
- **setup_distributed_wrapper.sh** - 环境设置封装器
- **setup_distributed_environment.sh** - 环境配置脚本
- **quick_setup_distributed.sh** - 快速设置脚本
- **enable_single_gpu_mode.sh** - 单GPU模式切换
- **restore_multi_gpu_mode.sh** - 多GPU模式恢复

## 使用顺序

1. `start_distributed_setup.sh` - 首次部署必须运行
2. `enable_single_gpu_mode.sh` / `restore_multi_gpu_mode.sh` - 根据需要切换模式
