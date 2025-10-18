'use client'

import Link from 'next/link'

export function Header() {
  return (
    <header className="border-b border-gray-200 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center space-x-8">
            <Link href="/" className="text-xl font-bold text-gray-900 hover:text-gray-700">
              NFT Rental Marketplace
            </Link>
            <nav className="hidden md:flex space-x-6">
              <Link href="/browse" className="text-gray-600 hover:text-gray-900">
                Browse
              </Link>
              <Link href="/mylistings" className="text-gray-600 hover:text-gray-900">
                My Listings
              </Link>
              <Link href="/myrentals" className="text-gray-600 hover:text-gray-900">
                My Rentals
              </Link>
              <Link href="/account" className="text-gray-600 hover:text-gray-900">
                Account
              </Link>
            </nav>
          </div>
          <div className="flex items-center space-x-4">
            <button className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors">
              Connect Wallet
            </button>
          </div>
        </div>
      </div>
    </header>
  )
}