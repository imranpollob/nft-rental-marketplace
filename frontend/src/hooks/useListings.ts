'use client'

import { useMemo } from 'react'
import { mockListings, getUniqueCollections, filterListings } from '@/lib/mockData'
import { ListingFilters } from '@/lib/types'

export function useListings(filters?: ListingFilters) {
  const listings = useMemo(() => {
    if (!filters) return mockListings
    return filterListings(mockListings, filters)
  }, [filters])

  const collections = useMemo(() => getUniqueCollections(listings), [listings])

  return {
    listings,
    collections,
    isLoading: false,
    error: null,
  }
}

export function useListing(nftAddress: string, tokenId: string) {
  const tokenIdBigInt = BigInt(tokenId)

  const listing = useMemo(() => {
    return mockListings.find(l => l.nftAddress === nftAddress && l.tokenId === tokenIdBigInt) || null
  }, [nftAddress, tokenIdBigInt])

  return {
    listing,
    isLoading: false,
    error: null,
  }
}

export function useFeaturedListings(limit = 4) {
  const { listings, isLoading, error } = useListings()

  const featuredListings = useMemo(() => {
    return listings.slice(0, limit)
  }, [listings, limit])

  return {
    listings: featuredListings,
    isLoading,
    error,
  }
}