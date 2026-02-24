'use client'

import { createContext, useContext, useMemo, useState } from 'react'

const AppContext = createContext({ ready: false, setReady: (_value: boolean) => {} })

export function AppProvider({ children }: { children: React.ReactNode }) {
    const [ready, setReady] = useState(false)
    const value = useMemo(() => ({ ready, setReady }), [ready])
    return <AppContext.Provider value={value}>{children}</AppContext.Provider>
}

export function useAppContext() {
    return useContext(AppContext)
}
