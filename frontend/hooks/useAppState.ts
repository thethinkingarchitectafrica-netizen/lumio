'use client'

import { useState } from 'react'

export function useAppState() {
    const [state, setState] = useState<{ ready: boolean }>({ ready: true })
    return { state, setState }
}
