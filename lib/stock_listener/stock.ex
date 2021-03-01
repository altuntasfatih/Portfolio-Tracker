defmodule Stock do
  import Util

  defstruct id: "",
            name: "",
            count: 0,
            purchase_price: 0.0,
            total_cost: 0.0,
            current_price: 0.0,
            current_worth: 0,
            rate: 0.0,
            target_price: 0

  def new(id, name, stock_count, purchase_price, target_price) do
    %Stock{
      id: id,
      name: name,
      count: stock_count,
      purchase_price: purchase_price,
      target_price: target_price,
      total_cost: (purchase_price * stock_count) |> round_ceil
    }
    |> calculate(purchase_price)
  end

  def calculate(%Stock{} = stock, purchase_price) do
    current_worth = (stock.count * purchase_price) |> round_ceil

    %Stock{
      stock
      | current_price: purchase_price,
        current_worth: current_worth,
        rate: ((current_worth - stock.total_cost) / stock.total_cost * 100) |> round_ceil
    }
  end

  defimpl String.Chars, for: Stock do
    def to_string(stock) do
      "
      Stock name : #{stock.id}
      Stock count : #{stock.count}
      Purchase price : #{stock.count}
      Total cost : #{stock.total_cost}
      Current price : #{stock.current_price}
      Current worth : #{stock.current_worth}
      Target  price : #{stock.target_price}
      Rate : #{stock.rate}"
    end
  end
end
