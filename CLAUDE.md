# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview
A professional-grade Bash script suite for automated video encoding using FFmpeg with x265/HEVC codec. The system provides **multi-mode encoding support (CRF/ABR/CBR)**, intelligent content analysis with automatic profile selection, advanced complexity-based parameter optimization, and comprehensive batch processing capabilities.

## Core Architecture

### Main Script: `ffmpeg_encoder.sh`
The primary encoding engine with modular architecture sourcing specialized library modules:

**Library Dependencies (load order):**
```bash
lib/config.sh       # Profile definitions and constants
lib/utils.sh        # Logging, validation, help functions
lib/progress.sh     # Progress tracking and visualization
lib/analysis.sh     # Video analysis and complexity detection
lib/video_processing.sh  # Filter chains and parameter calculations
lib/profiles.sh     # Profile parsing and adaptation
lib/encoding.sh     # Multi-mode encoding functions
lib/profile_selector.sh  # Automatic profile selection
lib/web_search.sh   # Web search integration
```

**Core Functionality:**
- **Multi-Mode Encoding**: CRF (single-pass VBR), ABR (two-pass average bitrate), CBR (two-pass constant bitrate)
- **Automatic Profile Selection**: Integrated content analysis with web search validation
- **Content-Adaptive Parameters**: Dual-aware optimization using both content type and complexity analysis
- **Enhanced Progress Tracking**: Real-time progress bars with ETA calculation and file size estimation
- **UUID-Based Output Naming**: Automatic collision-free naming when output not specified

### Directory Processing
The main script handles both single files and directories. For directory processing:
- **Recursive file discovery**: Finds .mkv, .mp4, .mov, .m4v files
- **UUID-based naming**: All output files use `filename_UUID.ext` format in same directory
- **Individual file processing**: Each file processed with same parameters through `process_single_file()`

## Multi-Mode Encoding System

### 3 Professional Encoding Modes

**CRF Mode (`-m crf`)**:
- **Implementation**: Single-pass encoding using only CRF value
- **Function**: `run_crf_encoding()` in `lib/encoding.sh:88`
- **Parameters**: Removes all bitrate references from x265-params
- **Use Case**: Archival quality, variable file sizes
- **Technical**: `ffmpeg -crf [adaptive_crf] -preset slow` (no bitrate constraints)

**ABR Mode (`-m abr`)**:
- **Implementation**: Two-pass average bitrate encoding (default mode)
- **Function**: `run_abr_encoding()` in `lib/encoding.sh:234`
- **Pass 1**: Medium preset with `no-slow-firstpass=1` for fast analysis
- **Pass 2**: Profile-defined preset (slow for 1080p, medium for 4K)
- **Use Case**: Streaming delivery with predictable file sizes

**CBR Mode (`-m cbr`)**:
- **Implementation**: Two-pass constant bitrate with VBV buffer constraints
- **Function**: `run_cbr_encoding()` in `lib/encoding.sh:144`  
- **Buffer Logic**: `bufsize = bitrate * 1.5`, minrate = maxrate = target bitrate
- **Use Case**: Broadcast transmission with constant bandwidth requirements

## Encoding Profile System

### Available Profiles (6 Core Profiles)
Located in `lib/config.sh:26-31`:

| Profile | CRF | Content Type | Optimization Focus |
|---------|-----|--------------|-------------------|
| **`anime`** | 23 | anime | Animation tuning, enhanced deblocking, flat area efficiency |
| **`classic_anime`** | 22 | classic_anime | Film grain preservation, finer detail retention |
| **`3d_cgi`** | 22 | 3d_animation | Pixar-like CGI, complex textures, smooth gradients |
| **`3d_complex`** | 21 | 3d_animation | Arcane-like complex animation, enhanced detail |
| **`4k`** | 22 | mixed | General 4K balanced optimization |
| **`4k_heavy_grain`** | 21 | heavy_grain | Specialized grain preservation, selective SAO |

### Profile Structure
Each profile contains colon-separated parameters:
- **Metadata**: `title`, `base_bitrate`, `hdr_bitrate`, `content_type`
- **x265 Parameters**: All standard x265 encoding parameters
- **Special Handling**: Metadata fields removed during parameter extraction

### Content-Aware Parameter Adaptation

**Dual-Aware Optimization** (`lib/video_processing.sh:131-173`):
```bash
# Content-Type CRF Modifiers (calculate_adaptive_crf function)
anime: +0.2 CRF            # Reduced from +0.5 - modern anime needs more detail
classic_anime: +0.5 CRF    # Aggressive for traditional anime
3d_animation: -0.4 CRF     # Reduced from -0.8 - prevent over-optimization  
film: 0.0 CRF              # Baseline for live-action
heavy_grain: -0.8 CRF      # Lower CRF for grain preservation
light_grain: -0.3 CRF      # Moderate reduction for light grain
```

**Adaptive Bitrate Calculation** (`lib/video_processing.sh:92-128`):
```bash
# Content-Type Bitrate Modifiers (calculate_adaptive_bitrate function)
anime: 0.90               # Increased from 0.85 - modern anime complexity
classic_anime: 0.85       # Keep original for classic content
3d_animation: 1.05        # Reduced from 1.1 - avoid over-allocation
film: 1.0                 # Baseline
heavy_grain: 1.25         # Significant increase for grain preservation
```

## Intelligent Content Analysis

### Automatic Profile Selection System
**Entry Point**: `process_single_file()` when `-p auto` specified (line 36-90)

**Multi-Stage Process**:
1. **Video Analysis**: `analyze_video_simple()` in `lib/profile_selector.sh:10-87`
   - Basic properties: width, height, duration, fps, codec, bitrate
   - Grain level estimation based on resolution and bitrate heuristics
   - Motion analysis using scene change detection

2. **Content Classification**: `classify_content_enhanced()` in `lib/profile_selector.sh:190-252`
   - Technical classification using grain/motion thresholds
   - Optional web search validation with confidence scoring
   - Decision logic combining technical and web search results

3. **Profile Recommendation**: `recommend_profile_simple()` in `lib/profile_selector.sh:152-187`
   - Maps content type to appropriate resolution-based profile

### Web Search Integration
**Module**: `lib/web_search.sh`

**Title Extraction** (`extract_title_from_filename()` lines 7-63):
- **TV Show Pattern**: `Title.S01E01` format detection
- **Movie with Year**: `Title.2024` format detection  
- **Quality Indicators**: Removes resolution/format tags
- **Confidence Scoring**: Based on extraction method reliability

**Content Classification** (`perform_web_search_classification()` lines 66-168):
- **Search Query Generation**: Content-specific search terms
- **Simulation Mode**: Built-in content database for testing
- **Scoring System**: Weighted keyword analysis for content type detection

### Complexity Analysis System
**Module**: `lib/analysis.sh` - `perform_complexity_analysis()` function (lines 305-507)

**Multi-Sample Grain Detection**:
- **Temporal Sampling**: 5 percentage-based points across video duration (10%, 25%, 50%, 75%, 90%)
- **Multi-Method Analysis**: High-frequency noise, local variance, edge detection
- **Frame Extraction**: PNG frames for detailed analysis using ffmpeg + Python numpy
- **Dark Scene Analysis**: Additional analysis for low-light grain detection

**Complexity Metrics**:
```bash
# Enhanced complexity calculation (line 491)
complexity_score = (SI × 0.25) + (TI × 0.35) + (scene_changes × 1.5) + (grain_level × 8) + (texture_score × 0.3) + (frame_complexity × 0.25)
```

## Advanced Video Processing

### Automatic Crop Detection
**Function**: `detect_crop_values()` in `lib/analysis.sh:16-97`

**Multi-Temporal Sampling**:
- **Sample Points**: 60s from start, middle, 60s from end
- **HDR-Adaptive Thresholds**: crop_limit=24 (SDR) vs crop_limit=64 (HDR)
- **Frequency Analysis**: Most common crop value selected for stability
- **Validation Logic**: Only applies crops with >1% total pixel change

### HDR10 Support
**Detection**: `extract_hdr_metadata()` in `lib/analysis.sh:289-302`
- **Color Space Analysis**: bt2020 + smpte2084 transfer detection
- **Parameter Adaptation**: +2 CRF and HDR bitrate selection in profiles
- **Metadata Preservation**: BT.2020 color space with SMPTE2084 curves

### Filter Chain Construction
**Function**: `build_filter_chain()` in `lib/video_processing.sh:7-63`

**Pipeline Order**:
1. **Optional Denoising**: `hqdn3d=1:1:2:2` (light uniform grain reduction)
2. **Hardware Acceleration**: CUDA decode → hwdownload → CPU filters (with fallback)
3. **Cropping**: Manual override or automatic crop detection
4. **Scaling**: Resolution adjustment if specified

## Progress Visualization System

### Real-Time Progress Tracking
**Module**: `lib/progress.sh`

**Enhanced Progress Display** (`run_ffmpeg_with_progress()` lines 411-555):
- **Multi-Method Progress**: Time-based and frame-based progress calculation
- **File Size Estimation**: Real-time size projection based on current progress
- **Adaptive Update Intervals**: Resolution and complexity-aware update frequency
- **Stall Detection**: 15-second stall detection with automatic recovery

**Progress Bar Components**:
```
Description: [████████████████████████████████████░░░] 72.3% | ETA: 04:27 | Est: 2.1GB
```

### Comprehensive Logging System
**Module**: `lib/utils.sh`

**Color-Coded Output**:
- **INFO** (Green): General information
- **WARN** (Yellow): Warnings and fallbacks
- **ERROR** (Red): Critical errors
- **DEBUG** (Blue): Debug information  
- **ANALYSIS** (Purple): Complexity analysis results
- **CROP** (Cyan): Crop detection information
- **PROFILE** (Cyan): Profile selection details

## Common Commands

### Single File Encoding with All Modes

**CRF Mode (Quality-Based, Variable Size)**:
```bash
# Auto-selection with UUID output
./ffmpeg_encoder.sh -i input.mkv -p auto -m crf

# Specific profile with custom output
./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p anime -m crf

# With complexity analysis and denoising
./ffmpeg_encoder.sh -i input.mkv -p 4k_heavy_grain -m crf --use-complexity --denoise
```

**ABR Mode (Streaming/Delivery, Predictable Size)**:
```bash
# Default mode (ABR) with auto-selection
./ffmpeg_encoder.sh -i input.mkv -p auto

# With title metadata and complexity analysis
./ffmpeg_encoder.sh -i input.mkv -o stream.mkv -p 4k -m abr -t "Movie Title" --use-complexity
```

**CBR Mode (Broadcast/Live, Constant Bitrate)**:
```bash
# Constant bitrate for broadcast
./ffmpeg_encoder.sh -i input.mkv -o broadcast.mkv -p 4k -m cbr

# With manual crop override
./ffmpeg_encoder.sh -i input.mkv -p anime -m cbr -c 1920:800:0:140
```

### Directory/Batch Processing
```bash
# Auto-selection batch processing (all modes supported)
./ffmpeg_encoder.sh -i ~/Videos/Raw/ -p auto -m crf
./ffmpeg_encoder.sh -i ~/Videos/Raw/ -p auto -m abr  
./ffmpeg_encoder.sh -i ~/Videos/Raw/ -p auto -m cbr

# All output files automatically use UUID naming: filename_[UUID].ext
```

### Advanced Features Usage
```bash
# Automatic profile selection with web search
./ffmpeg_encoder.sh -i "Spirited Away (2001).mkv" -p auto --web-search

# Force web search even with high technical confidence
./ffmpeg_encoder.sh -i movie.mkv -p auto --web-search-force

# Disable web search, technical analysis only
./ffmpeg_encoder.sh -i movie.mkv -p auto --no-web-search

# Hardware acceleration with denoising
./ffmpeg_encoder.sh -i input.mkv -p 4k_heavy_grain --hardware --denoise
```

## Technical Implementation Details

### Mode-Specific Parameter Usage

| Mode | Uses CRF | Uses Bitrate | Passes | Quality Control | Function Location |
|------|----------|--------------|---------|-----------------|-------------------|
| **CRF** | ✅ Adaptive CRF only | ❌ Completely removed | 1 | Pure quality-based | `lib/encoding.sh:88` |
| **ABR** | ✅ For estimation | ✅ Adaptive bitrate | 2 | Quality + size balance | `lib/encoding.sh:234` |
| **CBR** | ✅ For estimation | ✅ + VBV constraints | 2 | Constant bandwidth | `lib/encoding.sh:144` |

### Stream Preservation Architecture
**Function**: `build_stream_mapping()` in `lib/video_processing.sh:66-89`

**Comprehensive Stream Handling**:
- **Audio Streams**: Lossless copy of all audio tracks without transcoding
- **Subtitle Streams**: All subtitle formats and languages preserved
- **Chapters & Metadata**: Navigation and metadata information transferred
- **Dynamic Detection**: Uses ffprobe to detect available streams

### Dependencies & Requirements
- **ffmpeg**: With libx265 support and advanced filters
- **ffprobe**: For stream analysis and metadata extraction
- **bc**: For floating-point arithmetic calculations in parameter adaptation
- **uuidgen**: For UUID-based output naming (prevents collisions)
- **jq**: For JSON processing in automatic profile selection
- **python3** with **numpy**: For advanced grain detection analysis (optional, has fallbacks)

## Important Implementation Notes for Claude Code Users

When working with this codebase, remember:

1. **Output Parameter Behavior**: 
   - `-o` parameter is optional and defaults to UUID-based naming (`input_UUID.ext`) in same directory
   - For directory processing, `-o` parameter is ignored - all files get UUID names automatically

2. **Mode Parameter Defaults**:
   - Default mode is `abr` if not specified
   - All modes work with all profiles and features (crop detection, HDR support, stream preservation)

3. **Complexity Analysis**:
   - **Manual profiles**: Use `--use-complexity` to enable adaptive parameter optimization  
   - **Auto selection**: Always uses complexity analysis regardless of `--use-complexity` flag
   - **Performance impact**: Adds ~2-5 minutes of analysis time but provides better quality optimization

4. **Content-Aware Optimization**:
   - **CRF mode**: Uses only adaptive CRF values, bitrate completely ignored
   - **ABR/CBR modes**: Use both adaptive CRF for quality estimation and adaptive bitrate for size control
   - **HDR content**: Automatically detected and gets +2 CRF and HDR-specific bitrate values

5. **Profile Selection Strategy**:
   - **Auto selection**: Best for unknown content, uses technical + web search analysis
   - **Manual selection**: Better when content type is known, faster processing
   - **Fallback logic**: Auto selection falls back to filename-based heuristics if analysis fails

6. **Batch Processing Architecture**:
   - No separate batch script - main script handles directories
   - UUID naming prevents any file overwrites in batch processing
   - Each file processed independently with same parameters

7. **Hardware Acceleration**:
   - CUDA hardware acceleration available with `--hardware` flag
   - Automatic fallback to software processing if hardware decode fails
   - Primarily used for decode and denoising filter acceleration

8. **Web Search Integration**:
   - **Default enabled**: Web search validation runs by default for auto-selection
   - **Configurable**: Can be forced with `--web-search-force` or disabled with `--no-web-search`
   - **Fallback design**: Technical analysis always available if web search fails

This script suite represents **state-of-the-art automated video encoding** with professional-grade multi-mode support, comprehensive content analysis, and robust error handling suitable for both individual use and enterprise workflows.

---

# Integration Notes for Claude Code Users

**System Complexity**: 2,372+ lines across 9 specialized modules  
**Architecture**: Modular design with sophisticated inter-module communication  
**Performance**: Production-ready with enterprise-grade error handling  
**Maintenance**: Well-documented with comprehensive logging for debugging

**Key Integration Points**:
1. **Main orchestrator**: `ffmpeg_encoder.sh` (entry point for all operations)
2. **Profile system**: `lib/config.sh` + `lib/profiles.sh` (encoding parameter management)
3. **Analysis engine**: `lib/analysis.sh` + `lib/profile_selector.sh` (AI content classification)
4. **Encoding core**: `lib/encoding.sh` + `lib/video_processing.sh` (multi-mode implementation)  
5. **Progress system**: `lib/progress.sh` + `lib/utils.sh` (real-time monitoring and logging)

**When modifying this codebase**:
- Understand the modular dependencies and load order
- Maintain the sophisticated error handling and fallback systems
- Preserve the UUID-based collision prevention in batch processing
- Test with the existing profile system before adding new profiles
- Ensure compatibility across all three encoding modes (CRF/ABR/CBR)

This represents **state-of-the-art video encoding automation** suitable for individual creators, streaming platforms, broadcast facilities, and enterprise media workflows.