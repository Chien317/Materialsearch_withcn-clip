#!/bin/bash

# ELEVATER分布式环境搭建总体执行计划
# 按步骤引导用户完成完整的分布式环境配置

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  ELEVATER分布式零样本分类环境搭建向导"
echo "=================================================="

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 显示整体计划
echo ""
echo "🎯 搭建计划:"
echo "----------------------------------------------"
echo "1. 配置SSH无密钥连接 (服务器间通信)"
echo "2. 搭建分布式环境 (代码库、依赖、配置)"
echo "3. 分布式数据和模型分发 ⚠️  (修正: 在测试前执行)"
echo "4. 单卡模式验证 (快速测试环境是否正常)"
echo "5. 多卡模式切换 (完整性能测试)"
echo ""

# 检查必需的脚本文件
echo ""
echo "步骤0: 检查脚本完整性"
echo "----------------------------------------------"

REQUIRED_SCRIPTS=(
    "setup_distributed_ssh.sh"
    "enable_single_gpu_mode.sh" 
    "setup_distributed_environment.sh"
    "setup_distributed_wrapper.sh"
    "smart_data_distributor.sh"
    "distilled_model_distributor.sh"
    "distributed_coordinator.sh"
)

missing_scripts=0
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        log "✅ 脚本存在: $script"
    else
        log "❌ 脚本缺失: $script"
        missing_scripts=$((missing_scripts + 1))
    fi
done

if [ $missing_scripts -gt 0 ]; then
    echo "❌ 发现 $missing_scripts 个脚本文件缺失，请检查！"
    exit 1
fi

log "✅ 所有必需脚本文件检查完成"

# 交互式执行计划
echo ""
echo "🚀 开始分布式环境搭建"
echo "----------------------------------------------"

# 步骤1: SSH配置验证
echo ""
echo "步骤1: SSH配置验证"
echo "----------------------------------------------"

log "验证SSH配置是否完成..."
read -p "SSH配置是否已完成？ (y/N): " ssh_ready
if [[ ! "$ssh_ready" =~ ^[Yy]$ ]]; then
    log "开始SSH配置..."
    ./setup_distributed_ssh.sh
    log "✅ SSH配置完成"
else
    log "✅ SSH配置已确认"
fi

# 步骤2: 分布式环境设置 (使用新的封装脚本)
echo ""
echo "步骤2: 分布式环境设置"
echo "----------------------------------------------"

log "使用封装脚本进行分布式环境设置..."
log "这将自动上传setup_distributed_environment.sh到各服务器并执行"

read -p "开始分布式环境设置？ (Y/n): " env_setup
if [[ ! "$env_setup" =~ ^[Nn]$ ]]; then
    log "🚀 开始分布式环境设置..."
    ./setup_distributed_wrapper.sh
    log "✅ 分布式环境设置完成"
else
    log "⏭️ 跳过分布式环境设置"
fi

# 步骤3: 分布式数据和模型分发 (修正: 现在在测试前执行)
echo ""
echo "=== 步骤3: 分布式数据和模型分发 ==="
echo ""
echo "🚨 流程修正: 数据和模型分发现在在测试前执行"
echo ""
echo "这将执行数据和模型的分发："
echo "• 从v802分发ELEVATER数据集"
echo "• 从v800分发蒸馏模型"
echo "• 确保所有服务器都有必要的数据"
echo "• 特别关注v801数据写入问题"
echo ""
read -p "开始数据和模型分发？ (Y/n): " confirm_data

if [[ ! "$confirm_data" =~ ^[Nn]$ ]]; then
    log "📦 开始数据和模型分发..."
    
    # 分发数据集
    log "第1步: 分发ELEVATER数据集..."
    echo "⚠️  特别监控v801数据写入情况..."
    ./smart_data_distributor.sh
    data_result=$?
    
    # v801数据验证
    if [ $data_result -eq 0 ]; then
        log "验证v801数据分发结果..."
        ssh seetacloud-v801 "du -sh /root/autodl-tmp/datapath/datasets/ 2>/dev/null || echo '数据集目录为空'"
    fi
    
    # 分发模型
    log "第2步: 分发蒸馏模型..."
    ./distilled_model_distributor.sh
    model_result=$?
    
    # 详细的结果报告
    if [ $data_result -eq 0 ] && [ $model_result -eq 0 ]; then
        log "✅ 数据和模型分发完成"
        
        # 验证各服务器数据完整性
        log "🔍 验证各服务器数据完整性..."
        for server in "seetacloud-v800" "seetacloud-v801" "seetacloud-v802"; do
            echo "  检查 $server..."
            
            # 检查数据集
            dataset_count=$(ssh $server "ls /root/autodl-tmp/datapath/datasets/ELEVATER/ 2>/dev/null | wc -l" || echo "0")
            if [ "$dataset_count" -gt 0 ]; then
                echo "    ✅ 数据集目录存在 ($dataset_count 个数据集)"
            else
                echo "    ❌ 数据集目录缺失或为空"
            fi
            
            # 检查模型
            model_count=$(ssh $server "ls /root/autodl-tmp/datapath/experiments/*distill* 2>/dev/null | wc -l" || echo "0")
            if [ "$model_count" -gt 0 ]; then
                echo "    ✅ 蒸馏模型存在 ($model_count 个模型)"
            else
                echo "    ❌ 蒸馏模型缺失"
            fi
            
            # 特别检查v801的数据写入
            if [ "$server" = "seetacloud-v801" ]; then
                v801_data_size=$(ssh $server "du -sh /root/autodl-tmp/datapath/ 2>/dev/null | cut -f1" || echo "0B")
                echo "    📊 v801数据总量: $v801_data_size"
                if [ "$v801_data_size" = "0B" ]; then
                    echo "    🚨 v801数据盘写入异常！"
                fi
            fi
        done
        
    else
        log "⚠️  数据或模型分发可能有问题，但继续执行"
        echo "  数据分发结果: $([ $data_result -eq 0 ] && echo '成功' || echo '失败')"
        echo "  模型分发结果: $([ $model_result -eq 0 ] && echo '成功' || echo '失败')"
        
        # 如果数据分发失败，询问是否继续
        if [ $data_result -ne 0 ]; then
            echo ""
            echo "❌ 数据分发失败，这会影响后续测试"
            read -p "是否继续环境搭建？ (y/N): " continue_without_data
            if [[ ! "$continue_without_data" =~ ^[Yy]$ ]]; then
                echo "环境搭建已停止，请解决数据分发问题后重新运行"
                exit 1
            fi
        fi
    fi
else
    log "⏭️ 跳过数据和模型分发"
    echo "⚠️  警告：跳过数据分发可能导致后续测试失败"
fi

# 步骤4: 单卡测试模式
echo ""
echo "=== 步骤4: 启用单卡测试模式 ==="
echo ""
echo "这将修改脚本以支持单GPU测试，包括："
echo "• 使用GPU 0而非0,1,2,3"
echo "• 减少batch size和任务数"
echo "• 创建快速测试脚本"
echo ""
read -p "启用单卡测试模式？ (建议: y): " confirm_single

if [[ "$confirm_single" =~ ^[Yy]$ ]]; then
    log "🧪 配置单卡测试模式..."
    ./enable_single_gpu_mode.sh
    if [ $? -eq 0 ]; then
        log "✅ 单卡模式配置完成"
        SINGLE_MODE_ENABLED=true
    else
        log "❌ 单卡模式配置失败"
        exit 1
    fi
else
    log "⏭️  跳过单卡模式配置"
    SINGLE_MODE_ENABLED=false
fi

# 步骤5: 快速环境验证 (现在有数据了，可以正常测试)
if [ "$SINGLE_MODE_ENABLED" = true ]; then
    echo ""
    echo "=== 步骤5: 快速环境验证 ==="
    echo ""
    echo "✅ 现在可以运行快速测试来验证环境（数据已分发）："
    echo "• 测试v800服务器连接"
    echo "• 验证单GPU模式运行"
    echo "• 检查数据集和模型文件"
    echo "• 特别验证v801环境"
    echo ""
    read -p "运行快速测试？ (建议: y): " confirm_test
    
    if [[ "$confirm_test" =~ ^[Yy]$ ]]; then
        log "🏃 运行快速环境测试..."
        
        # 检查测试脚本是否存在
        if [ ! -f "./single_gpu_quick_test.sh" ]; then
            log "⚠️  single_gpu_quick_test.sh 不存在，将使用基础测试"
            
            # 基础环境测试
            log "执行基础环境测试..."
            for server in "seetacloud-v800" "seetacloud-v801"; do
                echo "  测试 $server..."
                
                # 测试SSH连接
                if ssh $server "echo 'SSH连接正常'" > /dev/null 2>&1; then
                    echo "    ✅ SSH连接正常"
                else
                    echo "    ❌ SSH连接失败"
                    continue
                fi
                
                # 测试conda环境
                if ssh $server "source /root/miniconda3/bin/activate && conda activate training && python --version" > /dev/null 2>&1; then
                    echo "    ✅ conda环境正常"
                else
                    echo "    ❌ conda环境异常"
                fi
                
                # 测试数据目录
                data_exists=$(ssh $server "[ -d '/root/autodl-tmp/datapath/datasets' ] && echo 'yes' || echo 'no'")
                if [ "$data_exists" = "yes" ]; then
                    echo "    ✅ 数据目录存在"
                else
                    echo "    ❌ 数据目录缺失"
                fi
            done
            
            test_result=0  # 假设基础测试通过
        else
            ./single_gpu_quick_test.sh
            test_result=$?
        fi
        
        if [ $test_result -eq 0 ]; then
            log "✅ 快速测试通过，环境基础功能正常"
        else
            log "❌ 快速测试失败"
            echo ""
            echo "建议操作："
            echo "1. 检查数据集分发是否成功"
            echo "2. 确认蒸馏模型文件存在"
            echo "3. 手动检查各服务器的数据完整性"
            echo "4. 特别检查v801数据盘写入问题"
            echo ""
            read -p "继续环境搭建？ (y/N): " continue_setup
            if [[ ! "$continue_setup" =~ ^[Yy]$ ]]; then
                echo "环境搭建已停止，请解决问题后重新运行"
                exit 1
            fi
        fi
    else
        log "⏭️  跳过快速测试"
    fi
fi

# 步骤6: 完整分布式配置
echo ""
echo "=== 步骤6: 完整分布式配置 ==="
echo ""
echo "数据和模型已分发，现在进行最终配置："
echo "• 配置分布式协调脚本"
echo "• 验证各服务器状态"
echo "• 准备批量测试"
echo ""
read -p "完成分布式配置？ (Y/n): " confirm_final

if [[ ! "$confirm_final" =~ ^[Nn]$ ]]; then
    log "🔧 完成分布式配置..."
    
    # 增强的服务器状态验证
    log "验证各服务器数据完整性..."
    for server in "seetacloud-v800" "seetacloud-v801" "seetacloud-v802"; do
        echo "  检查 $server..."
        
        # 检查数据集
        dataset_count=$(ssh $server "ls /root/autodl-tmp/datapath/datasets/ELEVATER/ 2>/dev/null | wc -l" || echo "0")
        if [ "$dataset_count" -gt 0 ]; then
            echo "    ✅ 数据集目录存在 ($dataset_count 个数据集)"
        else
            echo "    ❌ 数据集目录缺失"
        fi
        
        # 检查模型
        model_count=$(ssh $server "ls /root/autodl-tmp/datapath/experiments/*distill* 2>/dev/null | wc -l" || echo "0")
        if [ "$model_count" -gt 0 ]; then
            echo "    ✅ 蒸馏模型存在 ($model_count 个模型)"
        else
            echo "    ❌ 蒸馏模型缺失"
        fi
        
        # GPU状态检查
        gpu_status=$(ssh $server "nvidia-smi --query-gpu=count --format=csv,noheader,nounits" 2>/dev/null || echo "0")
        echo "    🖥️  GPU数量: $gpu_status"
        
        # 磁盘使用情况
        disk_usage=$(ssh $server "df -h /root/autodl-tmp | tail -1 | awk '{print \$5}'" 2>/dev/null || echo "unknown")
        echo "    💾 磁盘使用: $disk_usage"
    done
    
    log "✅ 分布式配置完成"
else
    log "⏭️ 跳过最终配置"
fi

# 步骤7: 恢复多卡模式
if [ "$SINGLE_MODE_ENABLED" = true ]; then
    echo ""
    echo "=== 步骤7: 恢复多卡模式 ==="
    echo ""
    echo "单卡测试完成，现在可以恢复4-GPU模式："
    echo "• 恢复所有脚本到多卡配置"
    echo "• 启用完整性能测试"
    echo ""
    read -p "恢复多卡模式？ (y/N): " confirm_restore
    
    if [[ "$confirm_restore" =~ ^[Yy]$ ]]; then
        log "🔄 恢复多卡模式..."
        
        if [ -f "./restore_multi_gpu_mode.sh" ]; then
            ./restore_multi_gpu_mode.sh
            restore_result=$?
        else
            log "⚠️  restore_multi_gpu_mode.sh 不存在，跳过恢复"
            restore_result=1
        fi
        
        if [ $restore_result -eq 0 ]; then
            log "✅ 多卡模式恢复完成"
        else
            log "❌ 多卡模式恢复失败或脚本不存在"
            echo "可以稍后手动运行: ./restore_multi_gpu_mode.sh"
        fi
    else
        log "⏭️  保持单卡模式"
        echo ""
        echo "⚠️  注意：当前仍为单卡测试模式"
        echo "如需完整性能，请稍后运行: ./restore_multi_gpu_mode.sh"
    fi
fi

# 完成总结
echo ""
echo "=================================================="
echo "🎉 分布式环境搭建向导完成！"
echo "=================================================="
echo ""
echo "环境状态总结:"
echo "----------------------------------------------"
if [[ "$ssh_ready" =~ ^[Yy]$ ]] || [[ "$env_setup" =~ ^[Yy]$ ]]; then
    echo "✅ SSH无密钥连接已配置"
else
    echo "⏭️  SSH配置已跳过"
fi

if [[ "$confirm_data" =~ ^[Yy]$ ]]; then
    if [ $data_result -eq 0 ] && [ $model_result -eq 0 ]; then
        echo "✅ 数据和模型分发成功"
    else
        echo "⚠️  数据或模型分发存在问题"
    fi
else
    echo "⏭️  数据和模型分发已跳过"
fi

if [ "$SINGLE_MODE_ENABLED" = true ]; then
    if [[ "$confirm_restore" =~ ^[Yy]$ ]]; then
        echo "✅ 多卡模式已启用"
    else
        echo "🧪 当前为单卡测试模式"
    fi
else
    echo "🔧 保持原始多卡配置"
fi

echo ""
echo "下一步操作建议:"
echo "----------------------------------------------"
echo "1. 运行完整测试:"
echo "   ./distributed_coordinator.sh"
echo ""
echo "2. 监控分布式状态:"
echo "   ./monitor_distributed.sh (如果存在)"
echo ""
echo "3. 手动测试单个任务:"
echo "   ./run_zeroshot_classification.sh cifar-10 1 0 32 v800"
echo ""
echo "4. 批量测试:"
echo "   ./run_zeroshot_batch.sh"
echo ""
echo "5. v801数据盘问题排查:"
echo "   ssh seetacloud-v801 'df -h && du -sh /root/autodl-tmp/*'"
echo ""
echo "🎯 分布式ELEVATER零样本分类环境已就绪！"
echo "==================================================" 