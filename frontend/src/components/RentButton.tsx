'use client'

import { useState } from 'react'
import { RentalCost } from '@/lib/types'

interface RentButtonProps {
  nftAddress: `0x${string}`
  tokenId: bigint
  startDate: Date
  endDate: Date
  rentalCost: RentalCost
  disabled?: boolean
  onSuccess?: () => void
}

export function RentButton({
  nftAddress,
  tokenId,
  startDate,
  endDate,
  rentalCost,
  disabled = false,
  onSuccess,
}: RentButtonProps) {
  const [isProcessing, setIsProcessing] = useState(false)

  const handleRent = async () => {
    setIsProcessing(true)

    // Simulate blockchain transaction delay
    setTimeout(() => {
      setIsProcessing(false)
      alert('Rental successful! (Mock transaction)')
      onSuccess?.()
    }, 2000)
  }

  return (
    <button
      onClick={handleRent}
      disabled={disabled || isProcessing}
      className="w-full bg-blue-600 text-white py-3 px-4 rounded-md hover:bg-blue-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
    >
      {isProcessing ? 'Processing...' : 'Rent Now'}
    </button>
  )
}