;; Gaming Identity Contract
;; Player identity with achievements, guilds, and cross-game reputation

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PLAYER-NOT-FOUND (err u101))
(define-constant ERR-GUILD-NOT-FOUND (err u102))
(define-constant ERR-ACHIEVEMENT-EXISTS (err u103))
(define-constant ERR-ALREADY-IN-GUILD (err u104))
(define-constant ERR-INSUFFICIENT-LEVEL (err u105))
(define-constant ERR-GAME-NOT-REGISTERED (err u106))

;; Game categories
(define-constant GAME-TYPE-RPG u1)
(define-constant GAME-TYPE-STRATEGY u2)
(define-constant GAME-TYPE-FPS u3)
(define-constant GAME-TYPE-MOBA u4)
(define-constant GAME-TYPE-MMO u5)

;; Achievement tiers
(define-constant TIER-BRONZE u1)
(define-constant TIER-SILVER u2)
(define-constant TIER-GOLD u3)
(define-constant TIER-PLATINUM u4)
(define-constant TIER-LEGENDARY u5)

;; Data structures
(define-map player-profiles
    principal
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
)

(define-map registered-games
    uint
    {
        name: (string-ascii 100),
        developer: principal,
        game-type: uint,
        active: bool,
        player-count: uint,
        achievement-count: uint,
        contract-address: (optional principal)
    }
)

(define-map achievements
    { game-id: uint, achievement-id: uint }
    {
        name: (string-ascii 100),
        description: (string-ascii 256),
        tier: uint,
        rarity: uint, ;; 1-10000 (basis points)
        points: uint,
        requirements: (string-ascii 512),
        created-at: uint
    }
)

(define-map player-achievements
    { player: principal, game-id: uint, achievement-id: uint }
    {
        unlocked-at: uint,
        verified: bool,
        proof-hash: (optional (buff 32))
    }
)

(define-map guilds
    uint
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
)

(define-map guild-members
    { guild-id: uint, member: principal }
    {
        role: uint, ;; 1=member, 2=officer, 3=leader
        joined-at: uint,
        contribution-score: uint,
        last-active: uint
    }
)

(define-map cross-game-stats
    { player: principal, game-id: uint }
    {
        playtime: uint,
        skill-rating: uint,
        matches-played: uint,
        achievements-unlocked: uint,
        last-played: uint,
        game-level: uint
    }
)

(define-map leaderboards
    { game-id: uint, category: uint, season: uint }
    (list 100 { player: principal, score: uint, rank: uint })
)

;; Global state
(define-data-var next-game-id uint u1)
(define-data-var next-guild-id uint u1)
(define-data-var current-season uint u1)
(define-data-var contract-admin principal tx-sender)

;; Player profile management
(define-public (create-player-profile (gamertag (string-ascii 50)))
    (begin
        (asserts! (is-none (map-get? player-profiles tx-sender)) ERR-NOT-AUTHORIZED)
        (map-set player-profiles tx-sender {
            gamertag: gamertag,
            level: u1,
            total-playtime: u0,
            preferred-games: (list),
            guild-id: none,
            reputation-score: u100,
            created-at: block-height,
            last-active: block-height,
            verified-gamer: false
        })
        (ok true)
    )
)

(define-public (update-activity (playtime-delta uint) (game-id uint))
    (let (
        (profile (unwrap! (map-get? player-profiles tx-sender) ERR-PLAYER-NOT-FOUND))
        (game (unwrap! (map-get? registered-games game-id) ERR-GAME-NOT-REGISTERED))
        (current-stats (default-to 
            { playtime: u0, skill-rating: u1000, matches-played: u0, 
              achievements-unlocked: u0, last-played: u0, game-level: u1 }
            (map-get? cross-game-stats { player: tx-sender, game-id: game-id })))
    )
        (asserts! (get active game) ERR-GAME-NOT-REGISTERED)
        
        ;; Update player profile
        (map-set player-profiles tx-sender
            (merge profile {
                total-playtime: (+ (get total-playtime profile) playtime-delta),
                last-active: block-height,
                level: (calculate-player-level (+ (get total-playtime profile) playtime-delta))
            })
        )
        
        ;; Update game-specific stats
        (map-set cross-game-stats
            { player: tx-sender, game-id: game-id }
            (merge current-stats {
                playtime: (+ (get playtime current-stats) playtime-delta),
                matches-played: (+ (get matches-played current-stats) u1),
                last-played: block-height
            })
        )
        
        (ok true)
    )
)

;; Achievement system
(define-public (register-game 
    (name (string-ascii 100))
    (game-type uint)
    (contract-address (optional principal)))
    (let ((game-id (var-get next-game-id)))
        (map-set registered-games game-id {
            name: name,
            developer: tx-sender,
            game-type: game-type,
            active: true,
            player-count: u0,
            achievement-count: u0,
            contract-address: contract-address
        })
        (var-set next-game-id (+ game-id u1))
        (ok game-id)
    )
)

(define-public (create-achievement
    (game-id uint)
    (achievement-id uint)
    (name (string-ascii 100))
    (description (string-ascii 256))
    (tier uint)
    (rarity uint)
    (points uint)
    (requirements (string-ascii 512)))
    (let ((game (unwrap! (map-get? registered-games game-id) ERR-GAME-NOT-REGISTERED)))
        (asserts! (is-eq tx-sender (get developer game)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? achievements { game-id: game-id, achievement-id: achievement-id })) ERR-ACHIEVEMENT-EXISTS)
        
        (map-set achievements
            { game-id: game-id, achievement-id: achievement-id }
            {
                name: name,
                description: description,
                tier: tier,
                rarity: rarity,
                points: points,
                requirements: requirements,
                created-at: block-height
            }
        )
        
        ;; Update game achievement count
        (map-set registered-games game-id
            (merge game { achievement-count: (+ (get achievement-count game) u1) })
        )
        
        (ok true)
    )
)

(define-public (unlock-achievement 
    (player principal)
    (game-id uint)
    (achievement-id uint)
    (proof-hash (optional (buff 32))))
    (let (
        (game (unwrap! (map-get? registered-games game-id) ERR-GAME-NOT-REGISTERED))
        (achievement (unwrap! (map-get? achievements { game-id: game-id, achievement-id: achievement-id }) ERR-PLAYER-NOT-FOUND))
        (player-profile (unwrap! (map-get? player-profiles player) ERR-PLAYER-NOT-FOUND))
    )
        ;; Only game developer or authorized contract can unlock achievements
        (asserts! (or (is-eq tx-sender (get developer game))
                     (is-eq (some tx-sender) (get contract-address game))) ERR-NOT-AUTHORIZED)
        
        (map-set player-achievements
            { player: player, game-id: game-id, achievement-id: achievement-id }
            {
                unlocked-at: block-height,
                verified: true,
                proof-hash: proof-hash
            }
        )
        
        ;; Update player reputation based on achievement tier
        (let ((reputation-bonus (* (get points achievement) (get tier achievement))))
            (map-set player-profiles player
                (merge player-profile {
                    reputation-score: (+ (get reputation-score player-profile) reputation-bonus)
                })
            )
        )
        
        (ok true)
    )
)

;; Guild system
(define-public (create-guild 
    (name (string-ascii 100))
    (preferred-game uint)
    (public bool)
    (max-members uint))
    (let (
        (guild-id (var-get next-guild-id))
        (profile (unwrap! (map-get? player-profiles tx-sender) ERR-PLAYER-NOT-FOUND))
    )
        (asserts! (is-none (get guild-id profile)) ERR-ALREADY-IN-GUILD)
        (asserts! (>= (get level profile) u5) ERR-INSUFFICIENT-LEVEL) ;; Must be level 5+
        
        (map-set guilds guild-id {
            name: name,
            leader: tx-sender,
            member-count: u1,
            total-reputation: (get reputation-score profile),
            preferred-game: preferred-game,
            guild-level: u1,
            created-at: block-height,
            public: public,
            max-members: max-members
        })
        
        (map-set guild-members
            { guild-id: guild-id, member: tx-sender }
            {
                role: u3, ;; Leader
                joined-at: block-height,
                contribution-score: u100,
                last-active: block-height
            }
        )
        
        ;; Update player profile
        (map-set player-profiles tx-sender
            (merge profile { guild-id: (some guild-id) })
        )
        
        (var-set next-guild-id (+ guild-id u1))
        (ok guild-id)
    )
)

(define-public (join-guild (guild-id uint))
    (let (
        (guild (unwrap! (map-get? guilds guild-id) ERR-GUILD-NOT-FOUND))
        (profile (unwrap! (map-get? player-profiles tx-sender) ERR-PLAYER-NOT-FOUND))
    )
        (asserts! (is-none (get guild-id profile)) ERR-ALREADY-IN-GUILD)
        (asserts! (< (get member-count guild) (get max-members guild)) ERR-NOT-AUTHORIZED)
        
        (map-set guild-members
            { guild-id: guild-id, member: tx-sender }
            {
                role: u1, ;; Member
                joined-at: block-height,
                contribution-score: u0,
                last-active: block-height
            }
        )
        
        ;; Update guild stats
        (map-set guilds guild-id
            (merge guild {
                member-count: (+ (get member-count guild) u1),
                total-reputation: (+ (get total-reputation guild) (get reputation-score profile))
            })
        )
        
        ;; Update player profile
        (map-set player-profiles tx-sender
            (merge profile { guild-id: (some guild-id) })
        )
        
        (ok true)
    )
)

;; Utility functions
(define-private (calculate-player-level (total-playtime uint))
    (+ u1 (/ total-playtime u10000)) ;; Level up every 10k blocks of playtime
)

(define-public (update-skill-rating (player principal) (game-id uint) (new-rating uint))
    (let (
        (game (unwrap! (map-get? registered-games game-id) ERR-GAME-NOT-REGISTERED))
        (current-stats (default-to 
            { playtime: u0, skill-rating: u1000, matches-played: u0, 
              achievements-unlocked: u0, last-played: u0, game-level: u1 }
            (map-get? cross-game-stats { player: player, game-id: game-id })))
    )
        ;; Only game developer can update skill ratings
        (asserts! (is-eq tx-sender (get developer game)) ERR-NOT-AUTHORIZED)
        
        (map-set cross-game-stats
            { player: player, game-id: game-id }
            (merge current-stats { skill-rating: new-rating })
        )
        (ok true)
    )
)

;; Read functions
(define-read-only (get-player-profile (player principal))
    (map-get? player-profiles player)
)

(define-read-only (get-game-info (game-id uint))
    (map-get? registered-games game-id)
)

(define-read-only (get-achievement (game-id uint) (achievement-id uint))
    (map-get? achievements { game-id: game-id, achievement-id: achievement-id })
)

(define-read-only (has-achievement (player principal) (game-id uint) (achievement-id uint))
    (is-some (map-get? player-achievements { player: player, game-id: game-id, achievement-id: achievement-id }))
)

(define-read-only (get-guild (guild-id uint))
    (map-get? guilds guild-id)
)

(define-read-only (get-guild-member (guild-id uint) (member principal))
    (map-get? guild-members { guild-id: guild-id, member: member })
)

(define-read-only (get-cross-game-stats (player principal) (game-id uint))
    (map-get? cross-game-stats { player: player, game-id: game-id })
)

(define-read-only (get-player-level (total-playtime uint))
    (calculate-player-level total-playtime)
)