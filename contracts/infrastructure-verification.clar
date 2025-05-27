;; Infrastructure Verification Contract
;; Validates and registers public infrastructure assets

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ASSET_EXISTS (err u101))
(define-constant ERR_ASSET_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Asset verification status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)

;; Data structures
(define-map infrastructure-assets
  { asset-id: uint }
  {
    owner: principal,
    asset-type: (string-ascii 50),
    location: (string-ascii 100),
    construction-year: uint,
    verification-status: uint,
    verified-at: (optional uint),
    verifier: (optional principal)
  }
)

(define-map asset-metadata
  { asset-id: uint }
  {
    description: (string-ascii 500),
    technical-specs: (string-ascii 1000),
    maintenance-history: (string-ascii 1000)
  }
)

(define-data-var next-asset-id uint u1)
(define-data-var total-verified-assets uint u0)

;; Register new infrastructure asset
(define-public (register-asset
  (asset-type (string-ascii 50))
  (location (string-ascii 100))
  (construction-year uint)
  (description (string-ascii 500))
  (technical-specs (string-ascii 1000)))
  (let ((asset-id (var-get next-asset-id)))
    (asserts! (is-none (map-get? infrastructure-assets { asset-id: asset-id })) ERR_ASSET_EXISTS)

    (map-set infrastructure-assets
      { asset-id: asset-id }
      {
        owner: tx-sender,
        asset-type: asset-type,
        location: location,
        construction-year: construction-year,
        verification-status: STATUS_PENDING,
        verified-at: none,
        verifier: none
      }
    )

    (map-set asset-metadata
      { asset-id: asset-id }
      {
        description: description,
        technical-specs: technical-specs,
        maintenance-history: ""
      }
    )

    (var-set next-asset-id (+ asset-id u1))
    (ok asset-id)
  )
)

;; Verify infrastructure asset (admin only)
(define-public (verify-asset (asset-id uint) (approved bool))
  (let ((asset (unwrap! (map-get? infrastructure-assets { asset-id: asset-id }) ERR_ASSET_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get verification-status asset) STATUS_PENDING) ERR_INVALID_STATUS)

    (map-set infrastructure-assets
      { asset-id: asset-id }
      (merge asset {
        verification-status: (if approved STATUS_VERIFIED STATUS_REJECTED),
        verified-at: (some block-height),
        verifier: (some tx-sender)
      })
    )

    (if approved
      (var-set total-verified-assets (+ (var-get total-verified-assets) u1))
      true
    )

    (ok approved)
  )
)

;; Get asset information
(define-read-only (get-asset (asset-id uint))
  (map-get? infrastructure-assets { asset-id: asset-id })
)

;; Get asset metadata
(define-read-only (get-asset-metadata (asset-id uint))
  (map-get? asset-metadata { asset-id: asset-id })
)

;; Get total verified assets
(define-read-only (get-total-verified-assets)
  (var-get total-verified-assets)
)

;; Check if asset is verified
(define-read-only (is-asset-verified (asset-id uint))
  (match (map-get? infrastructure-assets { asset-id: asset-id })
    asset (is-eq (get verification-status asset) STATUS_VERIFIED)
    false
  )
)
