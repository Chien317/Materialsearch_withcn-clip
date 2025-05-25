// 创建Vue应用
const { createApp, ref, onMounted, onUnmounted } = Vue;
const { ElMessage, ElLoading } = ElementPlus;

// 格式化时间函数
function formatTime(seconds) {
    if (!seconds) return '00:00:00';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
}

// 配置axios默认值
axios.defaults.timeout = 30000; // 30秒超时
axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

const app = createApp({
    setup() {
        // 状态管理
        const isScanning = ref(false);
        const status = ref({
            total_images: 0,
            total_videos: 0,
            total_video_frames: 0,
            total_pexels_videos: 0,
            scanning_files: 0,
            remain_files: 0,
            remain_time: '',
            progress: 0
        });
        const activeTab = ref('0');
        const searchForm = ref({
            positive: '',
            negative: '',
            path: '',
            positive_threshold: 0.5,
            negative_threshold: 0.5,
            image_threshold: 0.7,
            top_n: 12,
            search_type: 0,  // 0: 文字搜图, 1: 以图搜图, 2: 文字搜视频, 3: 以图搜视频, 4: 图文相似度匹配, 5: 以图搜图(数据库), 6: 以图搜视频(数据库), 9: 文字搜pexels视频
            img_id: null,
            text: '',
            start_time: null,
            end_time: null
        });
        const timeFilter = ref(null);
        const searchResults = ref([]);
        const imageUrlList = ref([]);
        const files = ref([]);
        const timer = ref(null);

        // 方法定义
        const getStatus = async () => {
            try {
                const response = await axios.get('/api/status');
                status.value = response.data;
                status.value.remain_time = formatTime(status.value.remain_time);
                isScanning.value = response.data.status;
            } catch (error) {
                ElMessage.error('Failed to get status: ' + (error.response?.data || error.message));
            }
        };

        const scan = async () => {
            if (isScanning.value) {
                ElMessage.warning('Scan is already in progress');
                return;
            }
            try {
                const response = await axios.get('/api/scan');
                await getStatus();
                ElMessage.success('Scan started successfully');
            } catch (error) {
                ElMessage.error('Failed to start scan: ' + (error.response?.data || error.message));
            }
        };

        const cleanCache = async () => {
            try {
                await axios.post('/api/clean_cache');
                ElMessage.success('Cache cleaned successfully');
            } catch (error) {
                ElMessage.error('Failed to clean cache: ' + (error.response?.data || error.message));
            }
        };

        const handleExceed = () => {
            ElMessage.warning('Only one file can be uploaded at a time');
        };

        const handleUploadError = (error, file, fileList) => {
            console.error('Upload error:', error);
            ElMessage.error('Upload failed: ' + (error.message || 'Network error'));
        };

        const handleBeforeUpload = (file) => {
            const isImage = file.type.startsWith('image/');
            const isLt10M = file.size / 1024 / 1024 < 10;

            if (!isImage) {
                ElMessage.error('Only image files are allowed!');
                return false;
            }
            if (!isLt10M) {
                ElMessage.error('Image size can not exceed 10MB!');
                return false;
            }
            return true;
        };

        const handleUploadSuccess = async (response) => {
            try {
                if (response && response.status === 'success') {
                    ElMessage.success('File uploaded successfully');
                } else if (response && response.error) {
                    ElMessage.error('Upload failed: ' + response.error);
                } else {
                    ElMessage.error('Upload failed: Invalid response');
                }
            } catch (error) {
                console.error('Upload error:', error);
                ElMessage.error('Upload failed: ' + (error.message || 'Unknown error'));
            }
        };

        const search = async (type) => {
            const loadingInstance = ElLoading.service({ 
                fullscreen: true, 
                text: 'Searching...',
                background: 'rgba(0, 0, 0, 0.7)'
            });

            try {
                searchForm.value.search_type = type;
                if (timeFilter.value) {
                    searchForm.value.start_time = timeFilter.value[0].getTime() / 1000;
                    searchForm.value.end_time = timeFilter.value[1].getTime() / 1000;
                }

                // 验证搜索条件
                if ((type === 0 || type === 2) && !searchForm.value.positive && !searchForm.value.path) {
                    ElMessage.error('Please enter search content or path');
                    loadingInstance.close();
                    return;
                }

                const response = await axios.post('/api/match', searchForm.value);
                searchResults.value = response.data;
                files.value = searchResults.value.map(file => {
                    const fileData = {
                        ...file,
                        score: file.score || 0,
                        start_time: file.start_time || '',
                        end_time: file.end_time || ''
                    };
                    
                    if (type === 0 || type === 1 || type === 5) {
                        // 图片搜索
                        fileData.url = file.url || '';
                    } else if (type === 2 || type === 3 || type === 6) {
                        // 视频搜索
                        fileData.url = file.path ? getVideoUrl(file.path) : '';
                    }
                    return fileData;
                });

                if (type === 0 || type === 1 || type === 5) {
                    imageUrlList.value = files.value
                        .filter(file => file.url)
                        .map(file => file.url);
                    ElMessage.success(`Found ${files.value.length} images`);
                } else if (type === 2 || type === 3 || type === 6) {
                    ElMessage.success(`Found ${files.value.length} videos`);
                } else if (type === 4) {
                    ElMessage.success(`Similarity score: ${response.data.score}%`);
                } else if (type === 9) {
                    ElMessage.success(`Found ${files.value.length} Pexels videos`);
                }
            } catch (error) {
                ElMessage.error('Search failed: ' + (error.response?.data || error.message));
            } finally {
                loadingInstance.close();
            }
        };

        const searchFromImage = async (type, imageUrl) => {
            try {
                // 从URL中提取图片ID
                const imageId = imageUrl.split('/').pop().split('?')[0];
                if (!imageId) {
                    ElMessage.error('Invalid image ID');
                    return;
                }

                searchForm.value.search_type = type;
                searchForm.value.img_id = imageId;
                const response = await axios.post('/api/match', searchForm.value);
                searchResults.value = response.data;
                files.value = searchResults.value.map(file => {
                    const fileData = {
                        ...file,
                        score: file.score || 0,
                        start_time: file.start_time || '',
                        end_time: file.end_time || ''
                    };
                    
                    if (type === 5) {
                        // 图片搜索
                        fileData.url = file.url || '';
                    } else {
                        // 视频搜索
                        fileData.url = file.path ? getVideoUrl(file.path) : '';
                    }
                    return fileData;
                });

                if (type === 5) {
                    imageUrlList.value = files.value
                        .filter(file => file.url)
                        .map(file => file.url);
                }
            } catch (error) {
                ElMessage.error('Search failed: ' + (error.response?.data || error.message));
            }
        };

        const getImageUrl = (imageId) => {
            if (!imageId) return '';
            return `/api/get_image/${imageId}?thumbnail=1`;
        };

        const getVideoUrl = (videoPath) => {
            if (!videoPath) return '';
            return `/api/get_video/${btoa(videoPath)}`;
        };

        const downloadVideoClip = async (videoPath, startTime, endTime) => {
            if (!videoPath || !startTime || !endTime) {
                ElMessage.error('Invalid video parameters');
                return;
            }

            try {
                const response = await axios.get(`/api/download_video_clip/${btoa(videoPath)}/${startTime}/${endTime}`, {
                    responseType: 'blob'
                });
                const url = window.URL.createObjectURL(new Blob([response.data]));
                const link = document.createElement('a');
                link.href = url;
                link.download = videoPath.split('/').pop();
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
                window.URL.revokeObjectURL(url);
                ElMessage.success('Video clip downloaded successfully');
            } catch (error) {
                ElMessage.error('Failed to download video clip: ' + (error.response?.data || error.message));
            }
        };

        // 初始化
        onMounted(() => {
            getStatus();
            // 设置定时器，每5秒更新一次状态
            timer.value = setInterval(getStatus, 5000);
            
            // 初始化剪贴板功能
            new ClipboardJS('.copy', {
                text: function(trigger) {
                    return trigger.getAttribute('data-clipboard-text');
                }
            }).on('success', function() {
                ElMessage.success('Path copied to clipboard');
            }).on('error', function() {
                ElMessage.error('Failed to copy path');
            });
        });

        // 组件卸载时清除定时器
        onUnmounted(() => {
            if (timer.value) {
                clearInterval(timer.value);
            }
        });

        // 返回模板需要的数据和方法
        return {
            isScanning,
            status,
            activeTab,
            searchForm,
            timeFilter,
            searchResults,
            imageUrlList,
            files,
            scan,
            cleanCache,
            search,
            handleExceed,
            handleUploadError,
            handleBeforeUpload,
            handleUploadSuccess,
            searchFromImage,
            getImageUrl,
            getVideoUrl,
            downloadVideoClip
        };
    }
});

// 使用Element Plus
app.use(ElementPlus);

// 挂载应用
app.mount('#app'); 