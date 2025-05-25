#!/bin/bash

# ELEVATER数据集零样本分类分布式协调器
# 负责任务分配、进度监控、结果收集

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  ELEVATER零样本分类分布式测试协调器"
echo "=================================================="

# 配置参数
SERVERS=("seetacloud-v800" "seetacloud-v801" "seetacloud-v802")
SERVER_DESCS=("Master/Coordinator" "Worker-1" "Worker-2") 
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 检查断点续传功能
RESUME_MODE=false
LATEST_RESULT_DIR=""
if find . -name "distributed_results_*" -type d >/dev/null 2>&1; then
    LATEST_RESULT_DIR=$(find . -name "distributed_results_*" -type d | sort | tail -1)
    if [ -n "$LATEST_RESULT_DIR" ] && [ -f "$LATEST_RESULT_DIR/progress.json" ]; then
        echo "🔍 发现未完成的分布式测试: $LATEST_RESULT_DIR"
        echo "📊 检查进度状态..."
        
        # 检查已完成的任务数
        completed_count=0
        for server in "${SERVERS[@]}"; do
            result_count=$(ssh "$server" "find /root/autodl-tmp/datapath -name '*.json' 2>/dev/null | wc -l" 2>/dev/null || echo "0")
            completed_count=$((completed_count + result_count))
        done
        
        total_expected=36  # 总任务数
        
        if [ "$completed_count" -gt 0 ] && [ "$completed_count" -lt "$total_expected" ]; then
            echo "✅ 发现 $completed_count 个已完成的任务 (总共 $total_expected 个)"
            read -p "🚀 是否继续未完成的测试？(y/N): " resume_confirm
            if [[ "$resume_confirm" =~ ^[Yy]$ ]]; then
                RESUME_MODE=true
                RESULT_DIR="$LATEST_RESULT_DIR"
                echo "🔄 恢复模式: 继续未完成的分布式测试"
            fi
        elif [ "$completed_count" -ge "$total_expected" ]; then
            echo "✅ 上次测试已完成所有任务 ($completed_count/$total_expected)"
            echo "📊 查看最终报告: $LATEST_RESULT_DIR/final_report.txt"
            exit 0
        fi
    fi
fi

# 设置结果目录
if [ "$RESUME_MODE" = false ]; then
    RESULT_DIR="./distributed_results_${TIMESTAMP}"
fi
LOG_FILE="${RESULT_DIR}/coordinator.log"

# 创建结果目录 (如果不是恢复模式)
if [ "$RESUME_MODE" = false ]; then
    mkdir -p ${RESULT_DIR}
    mkdir -p ${RESULT_DIR}/logs
    mkdir -p ${RESULT_DIR}/tasks
    mkdir -p ${RESULT_DIR}/results
fi

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_FILE}
}

log "=== 分布式测试协调器启动 ==="

# 检查服务器连通性
echo ""
echo "步骤1: 检查服务器连通性"
echo "----------------------------------------------"
for i in "${!SERVERS[@]}"; do
    server=${SERVERS[i]}
    desc=${SERVER_DESCS[i]}
    
    if ssh -o ConnectTimeout=10 ${server} "echo 'connected'" >/dev/null 2>&1; then
        log "✅ ${server} (${desc}) - 连接成功"
    else
        log "❌ ${server} (${desc}) - 连接失败"
        echo "错误: 无法连接到服务器 ${server}"
        exit 1
    fi
done

# 检查环境状态
echo ""
echo "步骤2: 检查环境状态"
echo "----------------------------------------------"
for i in "${!SERVERS[@]}"; do
    server=${SERVERS[i]}
    desc=${SERVER_DESCS[i]}
    
    log "检查 ${server} 环境状态..."
    
    # 检查conda环境
    if ssh ${server} "source /root/miniconda3/etc/profile.d/conda.sh && conda env list | grep training" >/dev/null 2>&1; then
        log "✅ ${server} - Conda环境 'training' 存在"
    else
        log "❌ ${server} - Conda环境 'training' 不存在"
        echo "请先在 ${server} 上运行 setup_environment.sh"
        exit 1
    fi
    
    # 检查Chinese-CLIP代码库
    if ssh ${server} "[ -d '/root/autodl-tmp/Chinese-CLIP' ]"; then
        log "✅ ${server} - Chinese-CLIP代码库存在"
    else
        log "❌ ${server} - Chinese-CLIP代码库不存在"
        exit 1
    fi
    
    # 检查ELEVATER数据集
    if ssh ${server} "[ -d '/root/autodl-tmp/datapath/datasets/ELEVATER' ]"; then
        log "✅ ${server} - ELEVATER数据集存在"
    else
        log "❌ ${server} - ELEVATER数据集不存在"
        exit 1
    fi
    
    # 检查蒸馏模型
    model_count=$(ssh ${server} "ls /root/autodl-tmp/datapath/experiments/muge_finetune_*_distill/checkpoints/epoch_latest.pt 2>/dev/null | wc -l")
    if [ "$model_count" -ge 3 ]; then
        log "✅ ${server} - 蒸馏模型存在 (${model_count}个)"
    else
        log "❌ ${server} - 蒸馏模型不完整 (${model_count}个)"
        exit 1
    fi
    
    # 检查GPU状态
    gpu_count=$(ssh ${server} "nvidia-smi -L | wc -l" 2>/dev/null || echo "0")
    log "✅ ${server} - GPU数量: ${gpu_count}"
done

# 任务分配定义
echo ""
echo "步骤3: 任务分配"
echo "----------------------------------------------"

# 定义数据集和模型
ALL_DATASETS=("cifar-10" "cifar-100" "caltech-101" "oxford-flower-102" "food-101" "fgvc-aircraft-2013b-variants102" "eurosat_clip" "resisc45_clip" "country211")
ALL_MODELS=("team" "large" "huge" "baseline")

# 任务分配策略 (使用变量代替关联数组)
TASK_v800=""
TASK_v801=""
TASK_v802=""

# v800: team和large模型，前6个数据集
for model in "team" "large"; do
    for dataset in "${ALL_DATASETS[@]:0:6}"; do
        TASK_v800+="${model}:${dataset},"
    done
done

# v801: huge和baseline模型，前6个数据集  
for model in "huge" "baseline"; do
    for dataset in "${ALL_DATASETS[@]:0:6}"; do
        TASK_v801+="${model}:${dataset},"
    done
done

# v802: 所有模型，后3个数据集
for model in "${ALL_MODELS[@]}"; do
    for dataset in "${ALL_DATASETS[@]:6:3}"; do
        TASK_v802+="${model}:${dataset},"
    done
done

# 显示任务分配并生成任务文件
total_tasks=0

# 处理v800任务
tasks=${TASK_v800%,}  # 移除尾部逗号
task_count=$(echo "$tasks" | tr ',' '\n' | wc -l)
total_tasks=$((total_tasks + task_count))
log "seetacloud-v800: ${task_count} 个任务"
task_file="${RESULT_DIR}/tasks/seetacloud-v800.tasks"
echo "$tasks" | tr ',' '\n' > "$task_file"

# 处理v801任务
tasks=${TASK_v801%,}  # 移除尾部逗号
task_count=$(echo "$tasks" | tr ',' '\n' | wc -l)
total_tasks=$((total_tasks + task_count))
log "seetacloud-v801: ${task_count} 个任务"
task_file="${RESULT_DIR}/tasks/seetacloud-v801.tasks"
echo "$tasks" | tr ',' '\n' > "$task_file"

# 处理v802任务
tasks=${TASK_v802%,}  # 移除尾部逗号
task_count=$(echo "$tasks" | tr ',' '\n' | wc -l)
total_tasks=$((total_tasks + task_count))
log "seetacloud-v802: ${task_count} 个任务"
task_file="${RESULT_DIR}/tasks/seetacloud-v802.tasks"
echo "$tasks" | tr ',' '\n' > "$task_file"

# 显示示例任务
for server in seetacloud-v800 seetacloud-v801 seetacloud-v802; do
    task_file="${RESULT_DIR}/tasks/${server}.tasks"
    
    # 显示前几个任务作为示例
    head -3 "$task_file" | while read task; do
        model=$(echo $task | cut -d':' -f1)
        dataset=$(echo $task | cut -d':' -f2)
        log "  示例: ${model}模型 × ${dataset}数据集"
    done
done

# 计算剩余任务数 (如果是恢复模式)
if [ "$RESUME_MODE" = true ]; then
    remaining_tasks=$((total_tasks - completed_count))
    log "总任务数: ${total_tasks}"
    log "已完成: ${completed_count} 个任务"
    log "剩余任务: ${remaining_tasks} 个任务"
    
    if [ "$remaining_tasks" -eq 0 ]; then
        echo "✅ 所有任务已完成！无需继续执行。"
        echo "📊 查看最终报告: $LATEST_RESULT_DIR/final_report.txt"
        exit 0
    fi
else
    log "总任务数: ${total_tasks}"
fi

# 确认开始执行
echo ""
if [ "$RESUME_MODE" = true ]; then
    read -p "确认继续剩余的 ${remaining_tasks} 个任务？ (y/N): " confirm
else
    read -p "确认开始分布式测试？ (y/N): " confirm
fi
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log "分布式测试已取消"
    exit 0
fi

# 开始分布式执行
echo ""
echo "步骤4: 启动分布式执行"
echo "----------------------------------------------"

log "=== 开始分布式测试 ==="

# 创建或更新进度跟踪文件
progress_file="${RESULT_DIR}/progress.json"
if [ "$RESUME_MODE" = false ] || [ ! -f "$progress_file" ]; then
    echo '{"total_tasks": '$total_tasks', "completed_tasks": 0, "failed_tasks": 0, "start_time": "'$(date -Iseconds)'", "servers": {}}' > "$progress_file"
    log "📊 初始化进度跟踪文件"
else
    log "📊 使用现有进度跟踪文件 (恢复模式)"
fi

# 并行启动所有服务器的工作进程
pids=()
for i in "${!SERVERS[@]}"; do
    server=${SERVERS[i]}
    task_file="${RESULT_DIR}/tasks/${server}.tasks"
    server_log="${RESULT_DIR}/logs/${server}.log"
    
    log "启动 ${server} 工作进程..."
    
    # 在后台启动服务器任务
    (
        while read task; do
            if [ -z "$task" ]; then continue; fi
            
            model=$(echo $task | cut -d':' -f1)
            dataset=$(echo $task | cut -d':' -f2)
            
            # 检查是否已经完成 (断点续传功能)
            if [ "$RESUME_MODE" = true ]; then
                # 检查远程服务器上是否已有结果文件
                result_exists=$(ssh ${server} "find /root/autodl-tmp/datapath -name '*${dataset}*${model}*.json' 2>/dev/null | wc -l" 2>/dev/null || echo "0")
                if [ "$result_exists" -gt 0 ]; then
                    log "[$server] ⏭️  跳过已完成: ${model} × ${dataset}"
                    # 更新进度 (已完成的任务)
                    python3 - << PYTHON
import json
with open("$progress_file", "r") as f:
    data = json.load(f)
data["completed_tasks"] += 1
if "$server" not in data["servers"]:
    data["servers"]["$server"] = {"completed": 0, "failed": 0}
data["servers"]["$server"]["completed"] += 1
with open("$progress_file", "w") as f:
    json.dump(data, f, indent=2)
PYTHON
                    continue
                fi
            fi
            
            log "[$server] 开始: ${model} × ${dataset}"
            
            # 执行单个任务 (使用本地脚本 - 与单卡测试保持一致) 
            # 自动确认评估以避免交互式等待
            if echo "y" | ./run_zeroshot_classification.sh "${dataset}" "${model}" 0 32 "${server##*-}"
            then
                log "[$server] ✅ 完成: ${model} × ${dataset}"
                # 更新进度
                python3 - << PYTHON
import json
with open("$progress_file", "r") as f:
    data = json.load(f)
data["completed_tasks"] += 1
if "$server" not in data["servers"]:
    data["servers"]["$server"] = {"completed": 0, "failed": 0}
data["servers"]["$server"]["completed"] += 1
with open("$progress_file", "w") as f:
    json.dump(data, f, indent=2)
PYTHON
            else
                log "[$server] ❌ 失败: ${model} × ${dataset}"
                # 更新失败计数
                python3 - << PYTHON
import json
with open("$progress_file", "r") as f:
    data = json.load(f)
data["failed_tasks"] += 1
if "$server" not in data["servers"]:
    data["servers"]["$server"] = {"completed": 0, "failed": 0}
data["servers"]["$server"]["failed"] += 1
with open("$progress_file", "w") as f:
    json.dump(data, f, indent=2)
PYTHON
            fi
            
        done < "$task_file"
    ) > "$server_log" 2>&1 &
    
    pids+=($!)
done

# 监控进度
echo ""
echo "步骤5: 监控执行进度"
echo "----------------------------------------------"

monitor_interval=30  # 每30秒检查一次进度
while true; do
    # 检查是否所有进程都完成
    all_done=true
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            all_done=false
            break
        fi
    done
    
    if [ "$all_done" = true ]; then
        break
    fi
    
    # 显示当前进度
    if [ -f "$progress_file" ]; then
        completed=$(python3 -c "import json; print(json.load(open('$progress_file'))['completed_tasks'])")
        failed=$(python3 -c "import json; print(json.load(open('$progress_file'))['failed_tasks'])")
        progress=$((100 * (completed + failed) / total_tasks))
        
        log "进度: ${completed}/${total_tasks} 完成, ${failed} 失败 (${progress}%)"
        
        # 显示各服务器状态
        for server in "${SERVERS[@]}"; do
            server_completed=$(python3 -c "import json; data=json.load(open('$progress_file')); print(data['servers'].get('$server', {}).get('completed', 0))" 2>/dev/null || echo "0")
            server_failed=$(python3 -c "import json; data=json.load(open('$progress_file')); print(data['servers'].get('$server', {}).get('failed', 0))" 2>/dev/null || echo "0")
            log "  ${server}: ${server_completed} 完成, ${server_failed} 失败"
        done
    fi
    
    sleep $monitor_interval
done

# 等待所有进程完成
for pid in "${pids[@]}"; do
    wait "$pid"
done

# 收集结果
echo ""
echo "步骤6: 收集结果"
echo "----------------------------------------------"

log "=== 收集和汇总结果 ==="

# 从各服务器收集结果文件
for server in "${SERVERS[@]}"; do
    log "收集 ${server} 的结果文件..."
    server_result_dir="${RESULT_DIR}/results/${server}"
    mkdir -p "$server_result_dir"
    
    # 下载结果文件
    scp -r ${server}:/root/autodl-tmp/datapath/zeroshot_predictions/ "$server_result_dir/" 2>/dev/null || true
done

# 生成最终报告
final_report="${RESULT_DIR}/final_report.txt"
log "生成最终测试报告: ${final_report}"

cat > "$final_report" << EOF
ELEVATER数据集零样本分类分布式测试报告
======================================

测试时间: $(date)
协调器版本: distributed_coordinator.sh v1.0
总测试任务: ${total_tasks}

服务器配置:
EOF

for i in "${!SERVERS[@]}"; do
    server=${SERVERS[i]}
    desc=${SERVER_DESCS[i]}
    echo "- ${server}: ${desc}" >> "$final_report"
done

if [ -f "$progress_file" ]; then
    completed=$(python3 -c "import json; print(json.load(open('$progress_file'))['completed_tasks'])")
    failed=$(python3 -c "import json; print(json.load(open('$progress_file'))['failed_tasks'])")
    
    cat >> "$final_report" << EOF

执行结果:
- 成功完成: ${completed} 个任务
- 执行失败: ${failed} 个任务
- 成功率: $(( 100 * completed / (completed + failed) ))%

详细结果文件位置: ${RESULT_DIR}/results/
日志文件位置: ${RESULT_DIR}/logs/
EOF
fi

log "=== 分布式测试完成 ==="
log "最终报告: ${final_report}"
log "结果目录: ${RESULT_DIR}"

echo ""
echo "=================================================="
echo "🎉 分布式测试执行完毕！"
echo ""
echo "📊 查看最终报告: cat ${final_report}"
echo "📁 结果目录: ${RESULT_DIR}"
echo "📈 监控数据: ${progress_file}"
echo "==================================================" 