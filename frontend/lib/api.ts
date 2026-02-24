export async function fetcher(url: string) {
    const response = await fetch(url)
    if (!response.ok) throw new Error('Request failed')
    return response.json()
}
