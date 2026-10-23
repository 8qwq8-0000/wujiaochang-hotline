param(
	[string]$Ffmpeg = "c:\ffmpeg\bin\ffmpeg.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$kenneyRoot = Join-Path $projectRoot "art_sources/audio/third_party/kenney"
$combatRoot = Join-Path $projectRoot "assets/audio/sfx/combat"

if (-not (Test-Path -LiteralPath $Ffmpeg)) {
	$resolved = Get-Command ffmpeg -ErrorAction SilentlyContinue
	if ($null -eq $resolved) {
		throw "ffmpeg was not found. Pass -Ffmpeg with an executable path."
	}
	$Ffmpeg = $resolved.Source
}

function Build-Mix {
	param(
		[string[]]$Inputs,
		[string]$Filter,
		[string]$Output
	)

	$outputPath = Join-Path $projectRoot $Output
	$outputDirectory = Split-Path -Parent $outputPath
	New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
	$arguments = @("-hide_banner", "-loglevel", "error", "-y")
	foreach ($input in $Inputs) {
		$arguments += @("-i", (Join-Path $projectRoot $input))
	}
	$arguments += @(
		"-filter_complex", $Filter,
		"-map", "[out]",
		"-ar", "48000",
		"-ac", "1",
		"-c:a", "pcm_s16le",
		$outputPath
	)
	& $Ffmpeg @arguments
	if ($LASTEXITCODE -ne 0) {
		throw "ffmpeg failed while building $Output"
	}
}

$pistolBase = "assets/audio/sfx/combat/pistol_fire.wav"
$guardBase = "assets/audio/sfx/combat/guard_block.wav"
$hurtBase = "assets/audio/sfx/combat/player_hit.wav"
$deathBase = "assets/audio/sfx/combat/enemy_death.wav"

for ($index = 0; $index -lt 4; $index++) {
	$number = $index + 1
	Build-Mix -Inputs @(
		$pistolBase,
		"art_sources/audio/third_party/kenney/sci-fi-sounds/Audio/laserSmall_$($index.ToString('000')).ogg",
		"art_sources/audio/third_party/kenney/impact-sounds/Audio/impactMetal_light_$($index.ToString('000')).ogg"
	) -Filter "[0:a]atrim=duration=0.30,asetpts=PTS-STARTPTS,volume=0.80[b];[1:a]atrim=duration=0.28,asetpts=PTS-STARTPTS,highpass=f=650,volume=0.42[e];[2:a]atrim=duration=0.18,asetpts=PTS-STARTPTS,highpass=f=900,volume=0.30[m];[b][e][m]amix=inputs=3:normalize=0:dropout_transition=0,alimiter=limit=0.90:level=false,atrim=duration=0.32[out]" -Output "assets/audio/sfx/combat/weapon_fire/service_pistol_fire_$($number.ToString('00')).wav"

	Build-Mix -Inputs @(
		$pistolBase,
		"art_sources/audio/third_party/kenney/sci-fi-sounds/Audio/thrusterFire_$($index.ToString('000')).ogg",
		"art_sources/audio/third_party/kenney/sci-fi-sounds/Audio/explosionCrunch_$($index.ToString('000')).ogg"
	) -Filter "[0:a]atrim=duration=0.32,asetpts=PTS-STARTPTS,asetrate=40000,aresample=48000,volume=0.52[b];[1:a]atrim=duration=0.48,asetpts=PTS-STARTPTS,highpass=f=180,lowpass=f=7600,volume=0.68[t];[2:a]atrim=duration=0.42,asetpts=PTS-STARTPTS,highpass=f=90,lowpass=f=4200,volume=0.34[x];[b][t][x]amix=inputs=3:normalize=0:dropout_transition=0,alimiter=limit=0.88:level=false,atrim=duration=0.50[out]" -Output "assets/audio/sfx/combat/weapon_fire/scattergun_fire_$($number.ToString('00')).wav"

	Build-Mix -Inputs @(
		$pistolBase,
		"art_sources/audio/third_party/kenney/sci-fi-sounds/Audio/laserLarge_$($index.ToString('000')).ogg",
		"art_sources/audio/third_party/kenney/sci-fi-sounds/Audio/lowFrequency_explosion_$((($index % 2)).ToString('000')).ogg"
	) -Filter "[0:a]atrim=duration=0.30,asetpts=PTS-STARTPTS,asetrate=34000,aresample=48000,volume=0.32[b];[1:a]atrim=duration=0.78,asetpts=PTS-STARTPTS,highpass=f=120,volume=0.74[e];[2:a]atrim=duration=0.78,asetpts=PTS-STARTPTS,lowpass=f=320,volume=0.42[l];[b][e][l]amix=inputs=3:normalize=0:dropout_transition=0,alimiter=limit=0.88:level=false,atrim=duration=0.80[out]" -Output "assets/audio/sfx/combat/weapon_fire/rail_cannon_fire_$($number.ToString('00')).wav"

	Build-Mix -Inputs @(
		$guardBase,
		"art_sources/audio/third_party/kenney/impact-sounds/Audio/impactMetal_medium_$($index.ToString('000')).ogg"
	) -Filter "[0:a]atrim=duration=0.34,asetpts=PTS-STARTPTS,lowpass=f=5600,volume=0.68[b];[1:a]atrim=duration=0.30,asetpts=PTS-STARTPTS,lowpass=f=6800,volume=0.72[m];[b][m]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.88:level=false,atrim=duration=0.36[out]" -Output "assets/audio/sfx/combat/defense/block_metal_$($number.ToString('00')).wav"

	Build-Mix -Inputs @(
		$hurtBase,
		"art_sources/audio/third_party/kenney/impact-sounds/Audio/impactPunch_medium_$($index.ToString('000')).ogg"
	) -Filter "[0:a]atrim=duration=0.22,asetpts=PTS-STARTPTS,volume=0.76[b];[1:a]atrim=duration=0.36,asetpts=PTS-STARTPTS,highpass=f=70,lowpass=f=5200,volume=0.56[p];[b][p]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.88:level=false,atrim=duration=0.38[out]" -Output "assets/audio/sfx/combat/player/player_hurt_$($number.ToString('00')).wav"
}

$perfectEnergy = @("forceField_000.ogg", "forceField_001.ogg", "forceField_002.ogg")
$perfectZap = @("zap1.ogg", "zap2.ogg", "zapTwoTone.ogg")
for ($index = 0; $index -lt 3; $index++) {
	$number = $index + 1
	Build-Mix -Inputs @(
		"art_sources/audio/third_party/kenney/sci-fi-sounds/Audio/$($perfectEnergy[$index])",
		"art_sources/audio/third_party/kenney/digital-audio/Audio/$($perfectZap[$index])"
	) -Filter "[0:a]atrim=duration=0.34,asetpts=PTS-STARTPTS,highpass=f=520,volume=0.55[f];[1:a]atrim=duration=0.25,asetpts=PTS-STARTPTS,highpass=f=850,volume=0.52[z];[f][z]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.86:level=false,atrim=duration=0.36[out]" -Output "assets/audio/sfx/combat/defense/perfect_guard_energy_$($number.ToString('00')).wav"
}

$killTones = @("tone1.ogg", "twoTone1.ogg", "zapThreeToneUp.ogg")
for ($index = 0; $index -lt 3; $index++) {
	$number = $index + 1
	Build-Mix -Inputs @(
		$deathBase,
		"art_sources/audio/third_party/kenney/digital-audio/Audio/$($killTones[$index])"
	) -Filter "[0:a]atrim=duration=0.24,asetpts=PTS-STARTPTS,highpass=f=180,volume=0.34[b];[1:a]atrim=duration=0.22,asetpts=PTS-STARTPTS,highpass=f=720,volume=0.58[t];[b][t]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.84:level=false,atrim=duration=0.25[out]" -Output "assets/audio/sfx/combat/kills/kill_confirm_$($number.ToString('00')).wav"
}

for ($index = 0; $index -lt 2; $index++) {
	$number = $index + 1
	Build-Mix -Inputs @(
		"art_sources/audio/third_party/kenney/sci-fi-sounds/Audio/lowFrequency_explosion_$($index.ToString('000')).ogg",
		"art_sources/audio/third_party/kenney/impact-sounds/Audio/impactMetal_heavy_$($index.ToString('000')).ogg"
	) -Filter "[0:a]atrim=duration=0.62,asetpts=PTS-STARTPTS,lowpass=f=420,volume=0.64[l];[1:a]atrim=duration=0.42,asetpts=PTS-STARTPTS,lowpass=f=2400,volume=0.42[m];[l][m]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.84:level=false,atrim=duration=0.64[out]" -Output "assets/audio/sfx/combat/kills/heavy_kill_weight_$($number.ToString('00')).wav"

	Build-Mix -Inputs @(
		$hurtBase,
		"art_sources/audio/third_party/kenney/sci-fi-sounds/Audio/lowFrequency_explosion_$($index.ToString('000')).ogg"
	) -Filter "[0:a]atrim=duration=0.22,asetpts=PTS-STARTPTS,volume=0.42[b];[1:a]atrim=duration=0.48,asetpts=PTS-STARTPTS,lowpass=f=520,volume=0.48[l];[b][l]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.82:level=false,atrim=duration=0.50[out]" -Output "assets/audio/sfx/combat/player/heavy_damage_$($number.ToString('00')).wav"
}

Build-Mix -Inputs @(
	"art_sources/audio/third_party/kenney/digital-audio/Audio/lowThreeTone.ogg",
	$hurtBase
) -Filter "[0:a]atrim=duration=0.62,asetpts=PTS-STARTPTS,highpass=f=320,volume=1.40[t];[1:a]atrim=duration=0.16,asetpts=PTS-STARTPTS,lowpass=f=1200,volume=0.22[b];[t][b]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.80:level=false,atrim=duration=0.64[out]" -Output "assets/audio/sfx/combat/player/low_health_warning.wav"

Build-Mix -Inputs @(
	"art_sources/audio/third_party/kenney/impact-sounds/Audio/impactSoft_heavy_000.ogg",
	"art_sources/audio/third_party/kenney/impact-sounds/Audio/impactSoft_heavy_001.ogg"
) -Filter "[0:a]atrim=duration=0.20,asetpts=PTS-STARTPTS,lowpass=f=210,volume=0.66[a];[1:a]atrim=start=0.03:duration=0.20,asetpts=PTS-STARTPTS,adelay=145,lowpass=f=190,volume=0.45[b];[a][b]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.76:level=false,atrim=duration=0.38[out]" -Output "assets/audio/sfx/combat/player/low_health_heartbeat.wav"

Write-Output "Combat audio assets rebuilt under $combatRoot"
