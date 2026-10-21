import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";
import { REGION } from "./region";

initializeApp();
setGlobalOptions({ region: REGION, maxInstances: 10 });

export { placeOrder, confirmPayment, cancelOrder, updateOrderStatus } from "./orders";
export {
  onOrderCreated,
  onOrderUpdated,
  onMessageCreated,
  onReviewWritten,
  onProductDeleted,
  onUserUpdated,
  expireUnpaidOrders,
  monimeWebhook,
} from "./triggers";
export { deleteAccount } from "./account";
export { requestLoginCode, verifyLoginCode } from "./emailAuth";
