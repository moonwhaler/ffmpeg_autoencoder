#!/usr/bin/env bash

# Configuration Module for FFmpeg Encoder
# Contains all constants, color definitions, and profile definitions

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Temporary file settings
TEMP_DIR="/tmp"
STATS_PREFIX="ffmpeg_stats_$$"

# Base profile definitions
declare -A BASE_PROFILES

# HINT: You can add new profiles anytime and also tweak certain 
#       parameters. HDR parameters will be added in the process, 
#       if HDR was found in the source video.

# 720p/1080p profiles 

# Modern 2D Anime (flat colors, minimal texture) - Target VMAF: 92-95
BASE_PROFILES["1080p_anime"]="title=1080p Modern Anime/2D Animation:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:ref=4:psy-rd=1.0:psy-rdoq=1.0:aq-mode=3:aq-strength=0.8:deblock=1,1:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.8:limit-refs=3:b-intra:weightb:weightp:cutree:scenecut=60:keyint=300:min-keyint=25:me=hex:subme=2:base_bitrate=2400:hdr_bitrate=2800:content_type=anime"

# Classic Anime with grain (90s content, film sources) - Target VMAF: 88-92 
BASE_PROFILES["1080p_classic_anime"]="title=1080p Classic Anime/2D Animation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=6:ref=6:psy-rd=1.5:psy-rdoq=2.0:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.65:nr-intra=0:nr-inter=0:weightb:weightp:cutree:scenecut=40:keyint=240:min-keyint=24:me=umh:subme=3:base_bitrate=3800:hdr_bitrate=4400:content_type=classic_anime"

# 3D Animation/CGI (complex textures, gradients) - Target VMAF: 95-98
BASE_PROFILES["1080p_3d_animation"]="title=1080p 3D/CGI Animation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=8:b-adapt=2:ref=6:psy-rd=2.0:psy-rdoq=1.5:aq-mode=3:aq-strength=1.0:deblock=0,0:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.65:b-intra:weightb:weightp:cutree:strong-intra-smoothing:me=umh:subme=4:merange=28:scenecut=45:keyint=250:min-keyint=25:base_bitrate=5800:hdr_bitrate=6800:content_type=3d_animation"

# Modern Live-Action Film (balanced approach) - Target VMAF: 90-94
BASE_PROFILES["1080p_film"]="title=1080p Live-Action Film:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=8:b-adapt=2:ref=6:psy-rd=2.0:psy-rdoq=1.0:aq-mode=2:aq-strength=0.8:deblock=0,0:rc-lookahead=80:ctu=64:rd=4:rdoq-level=2:qcomp=0.60:b-intra:weightb:weightp:cutree:me=umh:subme=3:merange=24:scenecut=40:keyint=240:min-keyint=24:base_bitrate=4600:hdr_bitrate=5400:content_type=film"

# Heavy Grain Film (classic films, archival) - Target VMAF: 85-90
BASE_PROFILES["1080p_heavygrain_film"]="title=1080p Heavy Grain Film:preset=slow:crf=17:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=5:b-adapt=2:ref=6:psy-rd=2.5:psy-rdoq=2.0:aq-mode=1:aq-strength=1.0:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.70:nr-intra=0:nr-inter=0:weightb:weightp:cutree:scenecut=30:keyint=300:min-keyint=25:me=umh:subme=4:merange=28:base_bitrate=6200:hdr_bitrate=7400:content_type=heavy_grain"

# Light grain preservation (older films, some anime)
BASE_PROFILES["1080p_light_grain"]="title=1080p Light Grain Preservation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=6:b-adapt=2:ref=6:psy-rd=1.8:psy-rdoq=1.8:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=4:rdoq-level=2:qcomp=0.75:nr-intra=0:nr-inter=0:weightb:weightp:cutree:me=umh:subme=3:base_bitrate=4200:hdr_bitrate=5000:content_type=light_grain"

# High-motion action content (sports, action films)
BASE_PROFILES["1080p_action"]="title=1080p High-Motion Action:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=4:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=1.0:aq-mode=3:aq-strength=0.9:deblock=0,0:rc-lookahead=40:ctu=64:rd=4:rdoq-level=2:qcomp=0.60:weightb:weightp:cutree:me=umh:subme=5:merange=32:scenecut=25:keyint=120:min-keyint=12:base_bitrate=5200:hdr_bitrate=6200:content_type=action"

# Ultra-clean digital content (modern anime, digital intermediates)
BASE_PROFILES["1080p_clean_digital"]="title=1080p Clean Digital Content:preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:b-adapt=2:ref=4:psy-rd=1.0:psy-rdoq=0.8:aq-mode=3:aq-strength=0.7:deblock=1,1:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.8:nr-intra=2:nr-inter=2:b-intra:weightb:weightp:cutree:me=hex:subme=2:base_bitrate=2800:hdr_bitrate=3300:content_type=clean_digital"

# 4K Profiles 

# Modern 4K Anime (optimized for performance) - Target VMAF: 92-95
BASE_PROFILES["4k_anime"]="title=4K Modern Anime/2D Animation:preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:ref=4:psy-rd=1.0:psy-rdoq=1.0:aq-mode=3:aq-strength=0.8:deblock=1,1:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.8:limit-refs=3:b-intra:weightb:weightp:cutree:scenecut=60:keyint=300:min-keyint=25:me=hex:subme=2:base_bitrate=6800:hdr_bitrate=8000:content_type=anime"

# Classic 4K Anime with grain preservation - Target VMAF: 88-92
BASE_PROFILES["4k_classic_anime"]="title=4K Classic Anime/2D Animation:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=6:ref=6:psy-rd=1.5:psy-rdoq=2.0:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.65:nr-intra=0:nr-inter=0:weightb:weightp:cutree:scenecut=40:keyint=240:min-keyint=25:me=umh:subme=3:base_bitrate=10200:hdr_bitrate=12000:content_type=classic_anime"

# 4K 3D Animation/CGI (balanced performance-quality) - Target VMAF: 95-98
BASE_PROFILES["4k_3d_animation"]="title=4K 3D/CGI Animation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=8:b-adapt=2:ref=5:psy-rd=2.0:psy-rdoq=1.5:aq-mode=3:aq-strength=1.0:deblock=0,0:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.65:b-intra:weightb:weightp:cutree:me=umh:subme=3:merange=24:scenecut=45:keyint=250:min-keyint=25:base_bitrate=13000:hdr_bitrate=15000:content_type=3d_animation"

# 4K Modern Film (production balance) - Target VMAF: 90-94
BASE_PROFILES["4k_film"]="title=4K Live-Action Film:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:sao:bframes=6:b-adapt=2:ref=5:psy-rd=2.0:psy-rdoq=1.0:aq-mode=2:aq-strength=0.8:deblock=0,0:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.60:weightb:weightp:cutree:me=umh:subme=3:merange=24:scenecut=40:keyint=240:min-keyint=25:base_bitrate=12600:hdr_bitrate=14800:content_type=film"

# 4K Heavy Grain Film (archival quality) - Target VMAF: 85-90
BASE_PROFILES["4k_heavygrain_film"]="title=4K Heavy Grain Film:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=5:b-adapt=2:ref=6:psy-rd=2.5:psy-rdoq=2.0:aq-mode=1:aq-strength=1.0:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.70:nr-intra=0:nr-inter=0:weightb:weightp:cutree:scenecut=30:keyint=300:min-keyint=25:me=umh:subme=3:merange=28:base_bitrate=14400:hdr_bitrate=17200:content_type=heavy_grain"

# Special Profile: Mixed content with moderate detail
BASE_PROFILES["4k_mixed_detail"]="title=4K Mixed Content Detail:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=6:b-adapt=2:ref=5:psy-rd=1.8:psy-rdoq=1.2:aq-mode=3:aq-strength=0.9:deblock=0,0:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.7:weightb:weightp:cutree:me=umh:subme=3:merange=24:base_bitrate=13800:hdr_bitrate=16000:content_type=mixed"

# Light grain preservation (older films, some anime)
BASE_PROFILES["4k_light_grain"]="title=4K Light Grain Preservation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=6:b-adapt=2:ref=6:psy-rd=1.8:psy-rdoq=1.8:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=4:rdoq-level=2:qcomp=0.75:nr-intra=0:nr-inter=0:weightb:weightp:cutree:me=umh:subme=3:base_bitrate=11600:hdr_bitrate=13800:content_type=light_grain"

# High-motion action content (sports, action films)
BASE_PROFILES["4k_action"]="title=4K High-Motion Action:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:sao:bframes=4:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=1.0:aq-mode=3:aq-strength=0.9:deblock=0,0:rc-lookahead=40:ctu=64:rd=4:rdoq-level=2:qcomp=0.60:weightb:weightp:cutree:me=umh:subme=4:merange=28:scenecut=25:keyint=120:min-keyint=12:base_bitrate=14000:hdr_bitrate=16800:content_type=action"

# Ultra-clean digital content (modern anime, digital intermediates)
BASE_PROFILES["4k_clean_digital"]="title=4K Clean Digital Content:preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:b-adapt=2:ref=4:psy-rd=1.0:psy-rdoq=0.8:aq-mode=3:aq-strength=0.7:deblock=1,1:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.8:nr-intra=2:nr-inter=2:weightb:weightp:cutree:me=hex:subme=2:base_bitrate=7800:hdr_bitrate=9200:content_type=clean_digital"

BASE_PROFILES["4k"]="title=4K general preset:preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=1.0:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=40:ctu=32:rd=4:rdoq-level=2:qcomp=0.70:weightb:weightp:cutree:me=umh:subme=3:base_bitrate=12000:hdr_bitrate=15000:content_type=mixed"
BASE_PROFILES["4k_heavy_grain"]="title=4K heavy grain (consider using --denoise):preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:selective-sao=2:deblock=-1,-1:aq-mode=3:psy-rd=0.8:psy-rdoq=1.0:rskip=2:rskip-edge-threshold=2:bframes=5:b-adapt=2:ref=6:rc-lookahead=60:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:vbv-maxrate=12000:vbv-bufsize=20000keyint=240:min-keyint=24:me=umh:subme=7:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=heavy_grain"
BASE_PROFILES["3d_cgi"]="title=3D CGI (Pixar-like):preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:limit-sao=1:deblock=1,1:aq-mode=3:aq-strength=0.9:psy-rd=1.6:psy-rdoq=1.5:rskip=2:rskip-edge-threshold=2:bframes=8:b-adapt=2:ref=5:rc-lookahead=60:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:weightb:weightp:cutree:vbv-maxrate=12000:vbv-bufsize=22000:keyint=240:min-keyint=24:me=umh:subme=7:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=3d_animation"
BASE_PROFILES["3d_complex"]="title=3D complex content (Arcane-like):preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:no-sao:deblock=1,1:aq-mode=3:aq-strength=1.0:psy-rd=2.0:psy-rdoq=2.5:rskip=2:rskip-edge-threshold=2:bframes=8:b-adapt=2:ref=6:rc-lookahead=60:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:weightb:weightp:cutree:vbv-maxrate=25000:vbv-bufsize=50000:keyint=240:min-keyint=24:me=hex:subme=6:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=3d_animation"
BASE_PROFILES["anime"]="title=Anime:preset=slow:crf=23:pix_fmt=yuv420p10le:profile=main10:limit-sao=1:deblock=1,1:aq-mode=3:aq-strength=0.8:psy-rd=1.1:psy-rdoq=1.0:rskip=2:rskip-edge-threshold=2:bframes=5:b-adapt=2:ref=6:rc-lookahead=80:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:vbv-maxrate=10000:vbv-bufsize=18000:keyint=240:min-keyint=24:me=hex:subme=6:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=anime"
BASE_PROFILES["classic_anime"]="title=Classic 90s Anime with finer details:preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:limit-sao=1:deblock=0,0:aq-mode=3:aq-strength=0.8:psy-rd=0.9:psy-rdoq=1.0:rskip=2:rskip-edge-threshold=2:bframes=5:b-adapt=2:ref=6:rc-lookahead=50:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:vbv-maxrate=10000:vbv-bufsize=18000:keyint=240:min-keyint=24:me=hex:subme=5:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=classic_anime"
