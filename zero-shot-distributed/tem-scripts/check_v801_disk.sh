#!/bin/bash

# v801数据盘异常检测独立脚本
# 用于诊断和排查v801服务器的数据盘问题

echo "=================================================="
echo "        v801数据盘异常检测工具"
echo "=================================================="

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 检查SSH连接
check_ssh_connection() {
    log "检查v801 SSH连接..."
    if ssh seetacloud-v801 "echo 'SSH连接正常'" > /dev/null 2>&1; then
        log "✅ SSH连接正常"
        return 0
    else
        log "❌ SSH连接失败，请检查网络和SSH配置"
        return 1
    fi
}

# v801数据盘详细检测
v801_disk_analysis() {
    log "🔍 开始v801磁盘详细分析..."
    
    ssh seetacloud-v801 << 'EOF'
        echo "=== v801磁盘分析报告 ==="
        echo "分析时间: $(date)"
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1. 磁盘挂载情况"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        df -h
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "2. 重点关注autodl-tmp分区"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        df -h | grep -E "(autodl-tmp|md127)" || echo "❌ 未找到autodl-tmp或md127分区"
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "3. 数据目录结构分析"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if [ -d "/root/autodl-tmp" ]; then
            echo "autodl-tmp目录存在，内容如下:"
            ls -la /root/autodl-tmp/
            echo ""
            
            echo "autodl-tmp磁盘使用情况:"
            du -sh /root/autodl-tmp/* 2>/dev/null || echo "目录为空或权限问题"
            echo ""
            
            if [ -d "/root/autodl-tmp/datapath" ]; then
                echo "✅ datapath目录存在"
                echo "datapath内容:"
                ls -la /root/autodl-tmp/datapath/
                echo ""
                
                echo "数据集目录检查:"
                if [ -d "/root/autodl-tmp/datapath/datasets" ]; then
                    echo "✅ datasets目录存在"
                    ls -la /root/autodl-tmp/datapath/datasets/
                    echo ""
                    
                    if [ -d "/root/autodl-tmp/datapath/datasets/ELEVATER" ]; then
                        echo "✅ ELEVATER目录存在"
                        echo "ELEVATER数据集数量: $(ls /root/autodl-tmp/datapath/datasets/ELEVATER/ 2>/dev/null | wc -l)"
                    else
                        echo "❌ ELEVATER目录不存在"
                    fi
                else
                    echo "❌ datasets目录不存在"
                fi
                echo ""
                
                echo "实验目录检查:"
                if [ -d "/root/autodl-tmp/datapath/experiments" ]; then
                    echo "✅ experiments目录存在"
                    ls -la /root/autodl-tmp/datapath/experiments/
                    echo ""
                    
                    echo "蒸馏模型检查:"
                    model_count=$(ls /root/autodl-tmp/datapath/experiments/*distill* 2>/dev/null | wc -l)
                    if [ $model_count -gt 0 ]; then
                        echo "✅ 找到 $model_count 个蒸馏模型"
                        ls -la /root/autodl-tmp/datapath/experiments/*distill* 2>/dev/null
                    else
                        echo "❌ 未找到蒸馏模型"
                    fi
                else
                    echo "❌ experiments目录不存在"
                fi
            else
                echo "❌ datapath目录不存在"
            fi
        else
            echo "❌ /root/autodl-tmp目录不存在"
        fi
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "4. 文件系统详细信息"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "块设备信息:"
        lsblk
        echo ""
        
        echo "挂载信息:"
        mount | grep -E "(autodl-tmp|md127)" || echo "未找到相关挂载"
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "5. 权限和所有权检查"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if [ -d "/root/autodl-tmp" ]; then
            echo "autodl-tmp权限:"
            ls -la /root/autodl-tmp/
            echo ""
            
            echo "当前用户权限测试:"
            if touch /root/autodl-tmp/test_write 2>/dev/null; then
                echo "✅ 可以写入autodl-tmp"
                rm -f /root/autodl-tmp/test_write
            else
                echo "❌ 无法写入autodl-tmp"
            fi
        fi
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "6. 内存和I/O状态"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "内存使用:"
        free -h
        echo ""
        
        echo "I/O统计 (近期):"
        iostat -x 1 1 2>/dev/null || echo "iostat命令不可用"
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "7. 系统日志检查 (与磁盘相关的错误)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "最近的磁盘相关错误:"
        journalctl --since "1 hour ago" | grep -i -E "(error|fail|disk|mount|md127)" | tail -10 || echo "未找到相关错误日志"
        echo ""
        
        echo "=== 分析完成 ==="
EOF
}

# 生成问题诊断和建议
generate_recommendations() {
    log "📋 生成诊断建议..."
    
    echo ""
    echo "=================================================="
    echo "           诊断建议和解决方案"
    echo "=================================================="
    echo ""
    
    echo "🔧 常见问题和解决方案:"
    echo ""
    echo "1. 如果autodl-tmp分区不存在或未挂载:"
    echo "   - 检查硬盘是否正确连接"
    echo "   - 重新挂载: sudo mount /dev/md127 /root/autodl-tmp"
    echo "   - 检查/etc/fstab中的挂载配置"
    echo ""
    
    echo "2. 如果权限问题:"
    echo "   - 修改所有权: sudo chown -R root:root /root/autodl-tmp"
    echo "   - 修改权限: sudo chmod -R 755 /root/autodl-tmp"
    echo ""
    
    echo "3. 如果磁盘空间不足:"
    echo "   - 清理临时文件: sudo rm -rf /root/autodl-tmp/tmp/*"
    echo "   - 检查大文件: du -sh /root/autodl-tmp/*"
    echo ""
    
    echo "4. 如果数据目录缺失:"
    echo "   - 创建必要目录:"
    echo "     mkdir -p /root/autodl-tmp/datapath/datasets"
    echo "     mkdir -p /root/autodl-tmp/datapath/experiments"
    echo ""
    
    echo "5. 重新同步数据:"
    echo "   - 重新运行数据分发: ./smart_data_distributor.sh"
    echo "   - 重新运行模型分发: ./distilled_model_distributor.sh"
    echo ""
    
    echo "6. 如果磁盘阵列问题:"
    echo "   - 检查RAID状态: cat /proc/mdstat"
    echo "   - 重建阵列: mdadm --assemble --scan"
    echo ""
}

# 主执行流程
main() {
    echo ""
    log "🚀 开始v801数据盘诊断..."
    
    # 检查SSH连接
    if ! check_ssh_connection; then
        echo "❌ SSH连接失败，无法进行诊断"
        exit 1
    fi
    
    # 执行详细分析
    v801_disk_analysis
    
    # 生成建议
    generate_recommendations
    
    echo ""
    log "✅ v801数据盘诊断完成"
    echo ""
    echo "📝 如需保存诊断报告，可运行:"
    echo "   ./check_v801_disk.sh > v801_disk_report_$(date +%Y%m%d_%H%M%S).txt"
    echo ""
    echo "🔄 如需重新运行完整环境搭建:"
    echo "   ./start_distributed_setup.sh"
}

# 执行主函数
main "$@" 