#!/usr/bin/env python3
"""
Convert any audio file to Telegram voice message format (OGG/Opus).

This script converts audio files to the exact format that Telegram
recognizes as voice messages, using the same parameters that work.

Usage:
    python convert_to_telegram_voice.py input.m4a [output.ogg]
    # Files longer than 5 minutes are automatically split into 5-minute segments
    
    python convert_to_telegram_voice.py input.m4a --duration 60  # Only first 60 seconds
    python convert_to_telegram_voice.py input.m4a --segment-duration 180  # 3-min segments
    python convert_to_telegram_voice.py input.m4a --no-split  # Disable auto-split
"""

import subprocess
import sys
from pathlib import Path
from typing import Optional

try:
    from mutagen.oggopus import OggOpus
except ImportError:
    print("Error: mutagen is required. Install it with: pip install mutagen")
    sys.exit(1)


def get_audio_duration(input_path: str) -> float:
    """Get duration of audio file in seconds."""
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", input_path],
            capture_output=True,
            text=True,
            check=True
        )
        return float(result.stdout.strip())
    except (subprocess.CalledProcessError, ValueError, FileNotFoundError):
        return 0.0


def convert_to_telegram_voice(
    input_path: str,
    output_path: Optional[str] = None,
    duration: Optional[float] = None,
    bitrate: str = "33k",
    auto_split: bool = False,
    segment_duration: float = 300.0,  # 5 minutes default
) -> list[str]:
    """
    Convert audio file to Telegram voice message format.
    
    Args:
        input_path: Path to input audio file
        output_path: Path to output OGG file (default: input.ogg)
            If auto_split is True, this is used as prefix for segment files
        duration: Maximum duration in seconds (None = full file)
        bitrate: Opus bitrate (default: "33k" to match speech.ogg)
        auto_split: If True, automatically split long files into segments
        segment_duration: Duration of each segment in seconds (default: 300 = 5 minutes)
    
    Returns:
        List of created output file paths (empty list if failed)
    """
    input_p = Path(input_path)
    if not input_p.exists():
        print(f"Error: Input file not found: {input_path}")
        return []
    
    # Check duration - auto-split if file is longer than segment_duration
    if duration is None:
        file_duration = get_audio_duration(str(input_p))
        if file_duration > segment_duration:
            # Automatically split long files
            return convert_with_auto_split(
                input_path, output_path, segment_duration, bitrate
            )
    
    # Single file conversion
    output_p = Path(output_path) if output_path else input_p.with_suffix(".ogg")
    
    if _convert_single_file(str(input_p), str(output_p), duration, bitrate):
        return [str(output_p)]
    return []


def convert_with_auto_split(
    input_path: str,
    output_path: Optional[str],
    segment_duration: float,
    bitrate: str,
) -> list[str]:
    """Split audio file into segments and convert each using the exact working command."""
    input_p = Path(input_path)
    file_duration = get_audio_duration(str(input_p))
    
    if file_duration == 0:
        print(f"Error: Could not determine duration of {input_path}")
        return []
    
    # Determine output file naming
    if output_path:
        output_base = Path(output_path).stem
        output_dir = Path(output_path).parent
        output_ext = Path(output_path).suffix or ".ogg"
    else:
        output_base = input_p.stem
        output_dir = input_p.parent
        output_ext = ".ogg"
    
    print(f"File duration: {file_duration:.1f} seconds")
    print(f"Splitting into segments of {segment_duration:.0f} seconds...")
    
    created_files = []
    segment_num = 0
    start_time = 0.0
    
    while start_time < file_duration:
        # Calculate actual segment duration (last segment might be shorter)
        segment_duration_actual = min(segment_duration, file_duration - start_time)
        segment_output = output_dir / f"{output_base}_{segment_num:03d}{output_ext}"
        
        print(f"  Creating segment {segment_num + 1}: {segment_output.name} "
              f"({start_time:.1f}s - {start_time + segment_duration_actual:.1f}s)")
        
        # Use exact working command: -i input -ss START -t DURATION -c:a libopus ...
        if _convert_single_file(
            str(input_p),
            str(segment_output),
            segment_duration_actual,  # duration
            bitrate,
            start_time=start_time,  # start time
        ):
            created_files.append(str(segment_output))
        else:
            print(f"  ✗ Failed to create segment {segment_num}")
            break
        
        segment_num += 1
        start_time += segment_duration
    
    print(f"✓ Created {len(created_files)} segment(s)")
    return created_files


def _convert_single_file(
    input_path: str,
    output_path: str,
    duration: Optional[float],
    bitrate: str,
    start_time: float = 0.0,
) -> bool:
    
    # Build ffmpeg command with EXACT parameters that worked for 91_voice_final_recreated.ogg
    # CRITICAL: -ss and -t must be IMMEDIATELY after -i, before all encoding parameters
    cmd = [
        "ffmpeg",
        "-i", input_path,
    ]
    
    # Add start time and duration RIGHT AFTER -i (exactly as in working command)
    # Always include -ss if we have start_time or duration
    if start_time > 0 or duration:
        cmd.extend(["-ss", str(start_time)])
    
    if duration:
        cmd.extend(["-t", str(duration)])
    
    # Now add all encoding parameters
    cmd.extend([
        "-vn",  # No video - CRITICAL for voice messages!
        "-c:a", "libopus",
        "-ar", "48000",
        "-ac", "1",
        "-b:a", bitrate,
        "-vbr", "on",
        "-application", "voip",
        "-frame_duration", "20",
        "-compression_level", "10",
        "-packet_loss", "0",
        "-dtx", "off",
        "-mapping_family", "0",
        "-map_metadata", "-1",  # Remove all metadata
        "-f", "ogg",
        "-y",  # Overwrite output
    ])
    
    cmd.append(output_path)
    
    # Run ffmpeg
    try:
        subprocess.run(
            cmd,
            check=True,
            capture_output=True,
            text=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Error during conversion: {e.stderr}")
        return False
    except FileNotFoundError:
        print("Error: ffmpeg not found. Please install ffmpeg.")
        return False
    
    # Fix metadata to match speech.ogg format
    try:
        target_tags = OggOpus(output_path)
        # Remove all tags
        for key in list(target_tags.keys()):
            del target_tags[key]
        
        # Set encoder tag to match speech.ogg exactly
        target_tags['encoder'] = ['Lavc60.40.100 libopus']
        target_tags.save()
    except Exception as e:
        # Metadata fix failed, but file should still be valid
        print(f"Warning: Could not fix metadata: {e}")
    
    return True


def main():
    """Command-line interface."""
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else None
    
    # Parse duration if specified
    duration = None
    if "--duration" in sys.argv:
        idx = sys.argv.index("--duration")
        if idx + 1 < len(sys.argv):
            try:
                duration = float(sys.argv[idx + 1])
            except ValueError:
                print("Error: --duration must be a number")
                sys.exit(1)
    
    # Parse bitrate if specified
    bitrate = "33k"
    if "--bitrate" in sys.argv:
        idx = sys.argv.index("--bitrate")
        if idx + 1 < len(sys.argv):
            bitrate = sys.argv[idx + 1]
    
    # Parse segment duration if specified
    segment_duration = 300.0  # 5 minutes default
    if "--segment-duration" in sys.argv:
        idx = sys.argv.index("--segment-duration")
        if idx + 1 < len(sys.argv):
            try:
                segment_duration = float(sys.argv[idx + 1])
            except ValueError:
                print("Error: --segment-duration must be a number")
                sys.exit(1)
    
    # Disable auto-split if --no-split is specified
    disable_auto_split = "--no-split" in sys.argv or "--no-auto-split" in sys.argv
    
    print(f"Converting {input_path}...")
    if not disable_auto_split:
        print(f"Auto-split enabled for files longer than {segment_duration:.0f} seconds")
    
    # If duration is specified or auto-split is disabled, don't auto-split
    if disable_auto_split or duration is not None:
        created_files = convert_to_telegram_voice(
            input_path,
            output_path,
            duration=duration,
            bitrate=bitrate,
            auto_split=False,
            segment_duration=segment_duration,
        )
    else:
        created_files = convert_to_telegram_voice(
            input_path,
            output_path,
            duration=duration,
            bitrate=bitrate,
            auto_split=True,
            segment_duration=segment_duration,
        )
    
    if created_files:
        print(f"\n✓ Success! Created {len(created_files)} file(s):")
        for f in created_files:
            print(f"  - {f}")
        sys.exit(0)
    else:
        print("\n✗ Conversion failed")
        sys.exit(1)


if __name__ == "__main__":
    main()

