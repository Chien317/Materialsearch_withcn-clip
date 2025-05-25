#!/bin/bash

# 分布式测试监控脚本
# 实时显示各服务器GPU状态和任务进度

SERVERS=("seetacloud-v800" "seetacloud-v801" "seetacloud-v802")
SERVER_NAMES=("v800-Master" "v801-Worker1" "v802-Worker2")

# 清屏函数
clear_screen() {
    clear
    echo "=================================================="
    echo "  ELEVATER分布式测试实时监控"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================================="
}

# 获取GPU状态
get_gpu_status() {
    local server=$1
    ssh -o ConnectTimeout=5 ${server} "nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits" 2>/dev/null || echo "连接失败"
}

# 获取任务进度
get_task_progress() {
    local server=$1
    ssh -o ConnectTimeout=5 ${server} "ps aux | grep zeroshot_evaluation.py | grep -v grep | wc -l" 2>/dev/null || echo "0"
}

# 主监控循环
while true; do
    clear_screen
    
    echo ""
    for i in "${!SERVERS[@]}"; do
        server=${SERVERS[i]}
        name=${SERVER_NAMES[i]}
        
        echo "【${name}】"
        echo "----------------------------------------"
        
        # GPU状态
        gpu_status=$(get_gpu_status ${server})
        if [ "$gpu_status" != "连接失败" ]; then
            echo "GPU状态:"
            echo "$gpu_status" | while IFS=',' read -r index gpu_name util mem_used mem_total temp; do
                util_bar=""
                util_num=${util%.*}  # 移除小数部分
                for ((j=0; j<util_num/10; j++)); do
                    util_bar+="█"
                done
                for ((j=util_num/10; j<10; j++)); do
                    util_bar+="░"
                done
                
                printf "  GPU%s: %3s%% │%s│ %s/%sMB %s°C\n" \
                    "$index" "$util" "$util_bar" "$mem_used" "$mem_total" "$temp"
            done
            
            # 任务状态
            running_tasks=$(get_task_progress ${server})
            echo "运行中任务: ${running_tasks}"
            
            # 系统负载
            load_avg=$(ssh -o ConnectTimeout=5 ${server} "uptime | awk -F'load average:' '{print \$2}'" 2>/dev/null || echo "N/A")
            echo "系统负载: ${load_avg}"
            
        else
            echo "❌ 服务器连接失败"
        fi
        
        echo ""
    done
    
    # 显示帮助信息
    echo "=========================================="
    echo "监控说明:"
    echo "- GPU使用率: ████████ 80%+ 高负载, ░░░░ 低负载"
    echo "- 按 Ctrl+C 退出监控"
    echo "- 更新间隔: 10秒"
    echo "=========================================="
    
    # 检查是否有进度文件
    if ls distributed_results_*/progress.json >/dev/null 2>&1; then
        latest_progress=$(ls -t distributed_results_*/progress.json | head -1)
        if [ -f "$latest_progress" ]; then
            echo ""
            echo "【分布式任务进度】"
            echo "----------------------------------------"
            total=$(python3 -c "import json; print(json.load(open('$latest_progress'))['total_tasks'])" 2>/dev/null || echo "N/A")
            completed=$(python3 -c "import json; print(json.load(open('$latest_progress'))['completed_tasks'])" 2>/dev/null || echo "N/A")
            failed=$(python3 -c "import json; print(json.load(open('$latest_progress'))['failed_tasks'])" 2>/dev/null || echo "N/A")
            
            if [ "$total" != "N/A" ] && [ "$completed" != "N/A" ]; then
                progress=$((100 * (completed + failed) / total))
                echo "总进度: ${completed}/${total} 完成, ${failed} 失败 (${progress}%)"
                
                # 进度条
                progress_bar=""
                for ((j=0; j<progress/2; j++)); do
                    progress_bar+="█"
                done
                for ((j=progress/2; j<50; j++)); do
                    progress_bar+="░"
                done
                echo "进度条: │${progress_bar}│ ${progress}%"
            fi
        fi
    fi
    
    sleep 10
done 