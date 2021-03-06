library(keras)
library(dplyr)
library(ggplot2)

K <- keras::backend()

n_samples <- 1000
n_features <- 1
n_hidden1 <- 128
n_hidden2 <- 128
n_output <- 1

learning_rate <- 1e-6
num_epochs <- 100
batch_size <- n_samples / 100

dropout <- 0.5
l2 <- 0.1

#X_train <- matrix(rnorm(n_samples * n_features, mean = 10, sd = 2), nrow = n_samples, ncol = n_features)
X_train <- matrix(c(-500, -200, 1:996 + rnorm(996, mean = 0, sd = 10), 1200, 1500),
                  nrow = 1000, ncol = 1)
dim(X_train)
coefs <- c(0.5)
#coefs <- c(0.5, -20, 11)
mu <- X_train %*% coefs
sigma = 2
y_train <- rnorm(n_samples, mu, sigma)

fit <- lm(y_train ~ X_train)
summary(fit)
 
model <- keras_model_sequential() 
model %>% 
  layer_dense(units = n_hidden1, activation = 'relu', input_shape = c(n_features)) %>% 
  layer_dropout(rate = dropout) %>% 
  layer_activity_regularization(l1=0, l2=l2) %>%
  layer_dense(units = n_hidden2, activation = 'relu') %>%
  layer_dropout(rate = dropout) %>%
  layer_activity_regularization(l1=0, l2=l2) %>%
  layer_dense(units = n_output, activation = 'linear')

model %>% summary()

model %>% compile(
  loss = 'mean_squared_error',
  optimizer = optimizer_adam())
  
history <- model %>% fit(
    X_train, y_train, 
    epochs = num_epochs, batch_size = batch_size, 
    validation_split = 0.2
  )

plot(history)

model$layers
get_output = K$`function`(list(model$layers[[1]]$input, K$learning_phase()), list(model$layers[[7]]$output))

# output in train mode = 1
layer_output = get_output(list(matrix(X_train[1:2, ], nrow=2), 1))
layer_output

# output in test mode = 0
layer_output = get_output(list(matrix(X_train[1:2, ], nrow=2), 0))
layer_output

layer_output = get_output(list(X_train, 0))
dim(layer_output[[1]])

# http://mlg.eng.cam.ac.uk/yarin/blog_3d801aa532c1ce.html
n <- 20
inclusion_prob <- 1-dropout
num_samples <- nrow(X_train)
weight_decay <- l2
length_scale <- 0.5

preds <- matrix(NA, nrow = nrow(X_train), ncol = n)
dim(preds)
for(i in seq_len(n)) {
  # train mode
  preds[ ,i] <- get_output(list(X_train, 1))[[1]]
}
dim(preds)

(predictive_mean <- apply(preds, 1, mean))
(predictive_var <-apply(preds, 1, var))
(tau <- length_scale^2 * inclusion_prob / (2 * num_samples * weight_decay))
(predictive_var <- predictive_var + tau^-1)

df <- data.frame(
  x = as.vector(X_train),
  pred_mean = predictive_mean,
  lwr = predictive_mean - sqrt(predictive_var),
  upr = predictive_mean + sqrt(predictive_var)
)

ggplot(df, aes(x = x, y=predictive_mean)) + geom_point() + 
  geom_ribbon(aes(ymin = lwr, ymax = upr), alpha = 0.2) 

