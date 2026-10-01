SzCoreLocales = {
    hu = {
        player_not_found = 'A játékos nem található.', invalid_amount = 'Érvénytelen összeg.',
        no_permission = 'Nincs jogosultságod ehhez.', inventory_full = 'Nincs elég hely az inventoryban.',
        item_missing = 'Nincs nálad elegendő tárgy.', vehicle_not_owned = 'Ez a jármű nem a tiéd.',
        paycheck = 'Fizetés érkezett: $%s', bill_received = 'Új számlát kaptál: $%s',
        bill_paid = 'A számla ki lett fizetve.', society_insufficient = 'Nincs elég pénz a society számlán.'
    },
    en = {
        player_not_found = 'Player not found.', invalid_amount = 'Invalid amount.',
        no_permission = 'You do not have permission.', inventory_full = 'Not enough inventory space.',
        item_missing = 'You do not have enough of that item.', vehicle_not_owned = 'You do not own this vehicle.',
        paycheck = 'Paycheck received: $%s', bill_received = 'You received a bill: $%s',
        bill_paid = 'Bill paid.', society_insufficient = 'Society account has insufficient funds.'
    }
}
function SzCoreLocale(key, ...)
    local lang = SzCoreConfig.Locale or 'hu'
    local pack = SzCoreLocales[lang] or SzCoreLocales.en
    local value = pack[key] or SzCoreLocales.en[key] or key
    if select('#', ...) > 0 then return string.format(value, ...) end
    return value
end
