# Gaming Identity Smart Contract

A comprehensive blockchain-based gaming identity system that enables cross-game player profiles, achievements, guilds, and reputation tracking on the Stacks blockchain.

## Overview

This smart contract provides a unified gaming identity infrastructure that allows players to:
- Create persistent gaming profiles across multiple games
- Earn and track achievements with verified proof systems
- Join guilds and build community reputation
- Maintain cross-game statistics and skill ratings
- Participate in seasonal leaderboards

## Features

### 🎮 Player Profiles
- Unique gamertags and persistent identity
- Level progression based on total playtime
- Cross-game reputation scoring
- Activity tracking and verification status

### 🏆 Achievement System
- Multi-tier achievement system (Bronze to Legendary)
- Rarity-based point allocation
- Cryptographic proof verification
- Developer-controlled achievement creation

### 🏰 Guild System
- Player-created guilds with role hierarchies
- Guild reputation and level progression
- Membership management with customizable limits
- Cross-game guild coordination

### 📊 Cross-Game Statistics
- Individual game statistics tracking
- Skill rating systems
- Match history and playtime records
- Seasonal leaderboard participation

## Contract Constants

### Game Types
- `GAME-TYPE-RPG` (1) - Role-playing games
- `GAME-TYPE-STRATEGY` (2) - Strategy games
- `GAME-TYPE-FPS` (3) - First-person shooters
- `GAME-TYPE-MOBA` (4) - Multiplayer online battle arenas
- `GAME-TYPE-MMO` (5) - Massively multiplayer online games

### Achievement Tiers
- `TIER-BRONZE` (1) - Basic achievements
- `TIER-SILVER` (2) - Intermediate achievements
- `TIER-GOLD` (3) - Advanced achievements
- `TIER-PLATINUM` (4) - Expert achievements
- `TIER-LEGENDARY` (5) - Legendary achievements

## Core Functions

### Player Management

#### `create-player-profile`
```clarity
(create-player-profile (gamertag (string-ascii 50)))
```
Creates a new player profile with a unique gamertag.

#### `update-activity`
```clarity
(update-activity (playtime-delta uint) (game-id uint))
```
Updates player activity, playtime, and game-specific statistics.

### Game Registration

#### `register-game`
```clarity
(register-game (name (string-ascii 100)) (game-type uint) (contract-address (optional principal)))
```
Registers a new game in the system. Only callable by game developers.

### Achievement System

#### `create-achievement`
```clarity
(create-achievement (game-id uint) (achievement-id uint) (name (string-ascii 100)) 
                   (description (string-ascii 256)) (tier uint) (rarity uint) 
                   (points uint) (requirements (string-ascii 512)))
```
Creates a new achievement for a registered game.

#### `unlock-achievement`
```clarity
(unlock-achievement (player principal) (game-id uint) (achievement-id uint) 
                   (proof-hash (optional (buff 32))))
```
Unlocks an achievement for a player with optional cryptographic proof.

### Guild Management

#### `create-guild`
```clarity
(create-guild (name (string-ascii 100)) (preferred-game uint) 
              (public bool) (max-members uint))
```
Creates a new guild. Requires player level 5 or higher.

#### `join-guild`
```clarity
(join-guild (guild-id uint))
```
Joins an existing guild if space is available.

### Skill Rating

#### `update-skill-rating`
```clarity
(update-skill-rating (player principal) (game-id uint) (new-rating uint))
```
Updates a player's skill rating for a specific game. Only callable by game developers.

## Read-Only Functions

### Player Data
- `get-player-profile (player principal)` - Retrieves player profile information
- `get-cross-game-stats (player principal) (game-id uint)` - Gets game-specific statistics
- `has-achievement (player principal) (game-id uint) (achievement-id uint)` - Checks achievement status

### Game Data
- `get-game-info (game-id uint)` - Retrieves registered game information
- `get-achievement (game-id uint) (achievement-id uint)` - Gets achievement details

### Guild Data
- `get-guild (guild-id uint)` - Retrieves guild information
- `get-guild-member (guild-id uint) (member principal)` - Gets guild member details

## Data Structures

### Player Profile
```clarity
{
    gamertag: (string-ascii 50),
    level: uint,
    total-playtime: uint,
    preferred-games: (list 5 uint),
    guild-id: (optional uint),
    reputation-score: uint,
    created-at: uint,
    last-active: uint,
    verified-gamer: bool
}
```

### Achievement
```clarity
{
    name: (string-ascii 100),
    description: (string-ascii 256),
    tier: uint,
    rarity: uint,
    points: uint,
    requirements: (string-ascii 512),
    created-at: uint
}
```

### Guild
```clarity
{
    name: (string-ascii 100),
    leader: principal,
    member-count: uint,
    total-reputation: uint,
    preferred-game: uint,
    guild-level: uint,
    created-at: uint,
    public: bool,
    max-members: uint
}
```

## Error Codes

- `ERR-NOT-AUTHORIZED (100)` - Insufficient permissions
- `ERR-PLAYER-NOT-FOUND (101)` - Player profile doesn't exist
- `ERR-GUILD-NOT-FOUND (102)` - Guild doesn't exist
- `ERR-ACHIEVEMENT-EXISTS (103)` - Achievement already created
- `ERR-ALREADY-IN-GUILD (104)` - Player already in a guild
- `ERR-INSUFFICIENT-LEVEL (105)` - Player level too low
- `ERR-GAME-NOT-REGISTERED (106)` - Game not in system

## Usage Examples

### For Players

1. **Create a Profile**
```clarity
(contract-call? .gaming-identity create-player-profile "ProGamer2024")
```

2. **Join a Guild**
```clarity
(contract-call? .gaming-identity join-guild u1)
```

### For Game Developers

1. **Register Your Game**
```clarity
(contract-call? .gaming-identity register-game "Epic Quest RPG" u1 none)
```

2. **Create Achievements**
```clarity
(contract-call? .gaming-identity create-achievement u1 u1 "First Steps" 
                "Complete the tutorial" u1 u9000 u10 "Finish tutorial quest")
```

3. **Award Achievements**
```clarity
(contract-call? .gaming-identity unlock-achievement 'ST1PLAYER123 u1 u1 none)
```

## Integration Guide

### For Game Developers

1. **Register your game** using `register-game`
2. **Create achievements** for your game using `create-achievement`
3. **Track player activity** by calling `update-activity` when players play
4. **Award achievements** using `unlock-achievement` when criteria are met
5. **Update skill ratings** based on player performance

### For Guild Leaders

1. **Reach level 5** by accumulating playtime across games
2. **Create your guild** with `create-guild`
3. **Manage members** and track guild progression
4. **Coordinate across games** using the preferred game system

## Security Features

- **Developer Authorization**: Only game developers can create achievements and update ratings
- **Profile Ownership**: Players fully control their own profiles
- **Guild Leadership**: Guild leaders have management privileges
- **Proof Verification**: Achievement unlocks can include cryptographic proofs
- **Activity Validation**: Game registration prevents unauthorized activity updates

## Roadmap

Future enhancements may include:
- Tournament and competition systems
- NFT integration for rare achievements
- Cross-chain compatibility
- Advanced analytics and insights
- Seasonal rewards and challenges
