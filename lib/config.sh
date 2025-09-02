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

BASE_PROFILES["4k"]="title=4K general preset:preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=1.0:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=40:ctu=32:rd=4:rdoq-level=2:qcomp=0.70:weightb:weightp:cutree:me=umh:subme=3:base_bitrate=12000:hdr_bitrate=15000:content_type=mixed"
BASE_PROFILES["4k_heavy_grain"]="title=4K heavy grain (consider using --denoise):preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:selective-sao=2:deblock=-1,-1:aq-mode=3:psy-rd=0.8:psy-rdoq=1.0:rskip=2:rskip-edge-threshold=2:bframes=5:b-adapt=2:ref=6:rc-lookahead=60:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:vbv-maxrate=12000:vbv-bufsize=20000keyint=240:min-keyint=24:me=umh:subme=7:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=heavy_grain"
BASE_PROFILES["3d_cgi"]="title=3D CGI (Pixar-like):preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:limit-sao=1:deblock=1,1:aq-mode=3:aq-strength=0.9:psy-rd=1.6:psy-rdoq=1.5:rskip=2:rskip-edge-threshold=2:bframes=8:b-adapt=2:ref=5:rc-lookahead=60:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:weightb:weightp:cutree:vbv-maxrate=12000:vbv-bufsize=22000:keyint=240:min-keyint=24:me=umh:subme=7:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=3d_animation"
BASE_PROFILES["3d_complex"]="title=3D complex content (Arcane-like):preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:no-sao:deblock=1,1:aq-mode=3:aq-strength=1.0:psy-rd=2.0:psy-rdoq=2.5:rskip=2:rskip-edge-threshold=2:bframes=8:b-adapt=2:ref=6:rc-lookahead=60:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:weightb:weightp:cutree:vbv-maxrate=25000:vbv-bufsize=50000:keyint=240:min-keyint=24:me=hex:subme=6:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=3d_animation"
BASE_PROFILES["anime"]="title=Anime:preset=slow:crf=23:pix_fmt=yuv420p10le:profile=main10:limit-sao=1:deblock=1,1:aq-mode=3:aq-strength=0.8:psy-rd=1.1:psy-rdoq=1.0:rskip=2:rskip-edge-threshold=2:bframes=5:b-adapt=2:ref=6:rc-lookahead=80:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:vbv-maxrate=10000:vbv-bufsize=18000:keyint=240:min-keyint=24:me=hex:subme=6:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=anime"
BASE_PROFILES["classic_anime"]="title=Classic 90s Anime with finer details:preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:limit-sao=1:deblock=0,0:aq-mode=3:aq-strength=0.8:psy-rd=0.9:psy-rdoq=1.0:rskip=2:rskip-edge-threshold=2:bframes=5:b-adapt=2:ref=6:rc-lookahead=50:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:vbv-maxrate=10000:vbv-bufsize=18000:keyint=240:min-keyint=24:me=hex:subme=5:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=classic_anime"
