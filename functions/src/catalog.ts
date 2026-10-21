// Server copy of the reference data. These are the values actually charged.
// Keep in sync with lib/core/constants/catalog.dart in the app.

export const DELIVERY_FEES: Record<string, number> = {
  Freetown: 40,
  Waterloo: 50,
  Lunsar: 80,
  "Port Loko": 85,
  Makeni: 90,
  Magburaka: 95,
  Bo: 100,
  Moyamba: 100,
  Kambia: 100,
  Kenema: 120,
  Pujehun: 130,
  Koidu: 140,
  Kabala: 140,
  Bonthe: 150,
  Kailahun: 150,
};

/** Minutes an online order waits for payment before it is cancelled and stock released. */
export const PAYMENT_WINDOW_MINUTES = 30;

export const MAX_ITEMS_PER_CHECKOUT = 50;
